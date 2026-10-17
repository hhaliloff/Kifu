#include "GTPBridge.h"

#include "../main.h"

#include <condition_variable>
#include <cstring>
#include <deque>
#include <iostream>
#include <memory>
#include <mutex>
#include <ostream>
#include <streambuf>
#include <string>
#include <thread>
#include <vector>

namespace {

class BlockingInputBuffer final : public std::streambuf {
 public:
  bool enqueueLine(const std::string& line) {
    {
      std::lock_guard<std::mutex> lock(mutex_);
      if(closed_)
        return false;
      for(char c : line)
        bytes_.push_back(c);
      bytes_.push_back('\n');
    }
    condition_.notify_all();
    return true;
  }

  bool waitUntilReadRequested() {
    std::unique_lock<std::mutex> lock(mutex_);
    condition_.wait(lock,[this]() { return readerReady_ || closed_; });
    return readerReady_;
  }

  void close() {
    {
      std::lock_guard<std::mutex> lock(mutex_);
      closed_ = true;
    }
    condition_.notify_all();
  }

 protected:
  int_type underflow() override {
    std::unique_lock<std::mutex> lock(mutex_);
    readerReady_ = true;
    condition_.notify_all();
    condition_.wait(lock,[this]() { return !bytes_.empty() || closed_; });
    if(bytes_.empty())
      return traits_type::eof();
    return traits_type::to_int_type(bytes_.front());
  }

  int_type uflow() override {
    std::unique_lock<std::mutex> lock(mutex_);
    readerReady_ = true;
    condition_.notify_all();
    condition_.wait(lock,[this]() { return !bytes_.empty() || closed_; });
    if(bytes_.empty())
      return traits_type::eof();
    const char c = bytes_.front();
    bytes_.pop_front();
    return traits_type::to_int_type(c);
  }

  std::streamsize xsgetn(char_type* destination, std::streamsize count) override {
    std::streamsize read = 0;
    while(read < count) {
      const int_type c = uflow();
      if(traits_type::eq_int_type(c,traits_type::eof()))
        break;
      destination[read++] = traits_type::to_char_type(c);
    }
    return read;
  }

 private:
  std::mutex mutex_;
  std::condition_variable condition_;
  std::deque<char> bytes_;
  bool readerReady_ = false;
  bool closed_ = false;
};

class GTPOutputBuffer final : public std::streambuf {
 public:
  int readResponse(char* destination, size_t capacity, size_t* responseLength) {
    std::unique_lock<std::mutex> lock(mutex_);
    condition_.wait(lock,[this]() { return !responses_.empty() || closed_; });
    if(responses_.empty())
      return KATAGO_GTP_STOPPED;

    const std::string& response = responses_.front();
    *responseLength = response.size();
    if(destination == nullptr || capacity <= response.size())
      return KATAGO_GTP_BUFFER_TOO_SMALL;

    std::memcpy(destination,response.data(),response.size());
    destination[response.size()] = '\0';
    responses_.pop_front();
    return KATAGO_GTP_OK;
  }

  void close() {
    {
      std::lock_guard<std::mutex> lock(mutex_);
      closed_ = true;
    }
    condition_.notify_all();
  }

 protected:
  std::streamsize xsputn(const char_type* source, std::streamsize count) override {
    if(count <= 0)
      return 0;
    {
      std::lock_guard<std::mutex> lock(mutex_);
      appendLocked(source,static_cast<size_t>(count));
    }
    condition_.notify_all();
    return count;
  }

  int_type overflow(int_type c) override {
    if(traits_type::eq_int_type(c,traits_type::eof()))
      return traits_type::not_eof(c);
    const char value = traits_type::to_char_type(c);
    {
      std::lock_guard<std::mutex> lock(mutex_);
      appendLocked(&value,1);
    }
    condition_.notify_all();
    return c;
  }

  int sync() override {
    return 0;
  }

 private:
  void appendLocked(const char* source, size_t count) {
    pending_.append(source,count);
    size_t end;
    while((end = pending_.find("\n\n")) != std::string::npos) {
      responses_.push_back(pending_.substr(0,end + 2));
      pending_.erase(0,end + 2);
    }
  }

  std::mutex mutex_;
  std::condition_variable condition_;
  std::deque<std::string> responses_;
  std::string pending_;
  bool closed_ = false;
};

class Session {
 public:
  Session()
    : input_(&inputBuffer_),
      output_(&outputBuffer_),
      stopRequested_(false) {}

  ~Session() {
    stopAndJoin();
  }

  void start(const std::string& configPath, const std::string& modelPath) {
    worker_ = std::thread([this,configPath,modelPath]() {
      run(configPath,modelPath);
    });
  }

  bool waitUntilReady() {
    return inputBuffer_.waitUntilReadRequested();
  }

  int sendCommand(const std::string& command) {
    if(command.find('\n') != std::string::npos || command.find('\r') != std::string::npos)
      return KATAGO_GTP_INVALID_ARGUMENT;
    std::lock_guard<std::mutex> lock(stopMutex_);
    if(stopRequested_ || !worker_.joinable())
      return KATAGO_GTP_STOPPED;
    return inputBuffer_.enqueueLine(command) ? KATAGO_GTP_OK : KATAGO_GTP_STOPPED;
  }

  int readResponse(char* destination, size_t capacity, size_t* responseLength) {
    return outputBuffer_.readResponse(destination,capacity,responseLength);
  }

  int stopAndJoin() {
    std::lock_guard<std::mutex> lock(stopMutex_);
    if(worker_.joinable()) {
      if(!stopRequested_) {
        stopRequested_ = true;
        inputBuffer_.enqueueLine("quit");
      }
      worker_.join();
    }
    return KATAGO_GTP_OK;
  }

 private:
  void run(const std::string& configPath, const std::string& modelPath) {
    try {
      const std::vector<std::string> args = {
        // TCLAP treats the first entry as argv[0], then parses single-dash options.
        "katago",
        "-config", configPath,
        "-model", modelPath
      };
      const int status = MainCmds::gtp(args,input_,output_);
      if(status != 0)
        std::cerr << "KataGo GTP bridge exited with status " << status << std::endl;
    }
    catch(const std::exception& error) {
      std::cerr << "KataGo GTP bridge failed: " << error.what() << std::endl;
    }
    catch(...) {
      std::cerr << "KataGo GTP bridge failed with an unknown exception" << std::endl;
    }
    inputBuffer_.close();
    output_.flush();
    outputBuffer_.close();
  }

  BlockingInputBuffer inputBuffer_;
  std::istream input_;
  GTPOutputBuffer outputBuffer_;
  std::ostream output_;
  std::thread worker_;
  std::mutex stopMutex_;
  bool stopRequested_;
};

std::mutex activeHandleMutex;
bool hasActiveHandle = false;

void releaseActiveHandle() {
  std::lock_guard<std::mutex> lock(activeHandleMutex);
  hasActiveHandle = false;
}

}  // namespace

struct KataGoGTPHandle {
  Session session;
};

extern "C" KataGoGTPHandle* katago_gtp_create(const char* configPath, const char* modelPath) {
  if(configPath == nullptr || modelPath == nullptr || configPath[0] == '\0' || modelPath[0] == '\0')
    return nullptr;

  {
    std::lock_guard<std::mutex> lock(activeHandleMutex);
    if(hasActiveHandle)
      return nullptr;
    hasActiveHandle = true;
  }

  try {
    std::unique_ptr<KataGoGTPHandle> handle(new KataGoGTPHandle());
    handle->session.start(configPath,modelPath);
    if(!handle->session.waitUntilReady()) {
      handle->session.stopAndJoin();
      releaseActiveHandle();
      return nullptr;
    }
    return handle.release();
  }
  catch(const std::exception& error) {
    std::cerr << "Could not create KataGo GTP bridge: " << error.what() << std::endl;
  }
  catch(...) {
    std::cerr << "Could not create KataGo GTP bridge" << std::endl;
  }
  releaseActiveHandle();
  return nullptr;
}

extern "C" int katago_gtp_send_command(KataGoGTPHandle* handle, const char* command) {
  if(handle == nullptr || command == nullptr)
    return KATAGO_GTP_INVALID_ARGUMENT;
  try {
    return handle->session.sendCommand(command);
  }
  catch(...) {
    return KATAGO_GTP_ERROR;
  }
}

extern "C" int katago_gtp_read_response(
  KataGoGTPHandle* handle,
  char* buffer,
  size_t capacity,
  size_t* responseLength
) {
  if(handle == nullptr || responseLength == nullptr || (buffer == nullptr && capacity != 0))
    return KATAGO_GTP_INVALID_ARGUMENT;
  try {
    return handle->session.readResponse(buffer,capacity,responseLength);
  }
  catch(...) {
    return KATAGO_GTP_ERROR;
  }
}

extern "C" int katago_gtp_stop(KataGoGTPHandle* handle) {
  if(handle == nullptr)
    return KATAGO_GTP_INVALID_ARGUMENT;
  try {
    return handle->session.stopAndJoin();
  }
  catch(...) {
    return KATAGO_GTP_ERROR;
  }
}

extern "C" void katago_gtp_destroy(KataGoGTPHandle* handle) {
  if(handle == nullptr)
    return;
  try {
    handle->session.stopAndJoin();
  }
  catch(...) {
  }
  delete handle;
  releaseActiveHandle();
}
