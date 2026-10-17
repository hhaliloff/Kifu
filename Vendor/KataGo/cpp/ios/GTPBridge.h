#ifndef KATAGO_IOS_GTP_BRIDGE_H_
#define KATAGO_IOS_GTP_BRIDGE_H_

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct KataGoGTPHandle KataGoGTPHandle;

enum KataGoGTPStatus {
  KATAGO_GTP_OK = 0,
  KATAGO_GTP_BUFFER_TOO_SMALL = 1,
  KATAGO_GTP_STOPPED = 2,
  KATAGO_GTP_INVALID_ARGUMENT = -1,
  KATAGO_GTP_ERROR = -2
};

/*
 * Creates the in-process engine and waits until config/model initialization is
 * complete. Only one KataGo GTP bridge may be active in a process. Returns
 * NULL on invalid paths or startup failure; diagnostics are written to stderr.
 */
KataGoGTPHandle* katago_gtp_create(const char* config_path, const char* model_path);

/* Sends one GTP command line. Embedded CR/LF are rejected; an empty command
 * line is accepted and can be used to cancel an active analysis command. */
int katago_gtp_send_command(KataGoGTPHandle* handle, const char* command);

/* Blocks until a complete response (including the terminating blank line) is
 * available. response_length receives the byte count excluding the NUL. If
 * capacity is too small, BUFFER_TOO_SMALL is returned and the response stays
 * queued; capacity must include room for the NUL terminator. */
int katago_gtp_read_response(
  KataGoGTPHandle* handle,
  char* buffer,
  size_t capacity,
  size_t* response_length
);

/* Sends quit and joins the engine thread. */
int katago_gtp_stop(KataGoGTPHandle* handle);

/* Stops the engine if needed and releases the handle. */
void katago_gtp_destroy(KataGoGTPHandle* handle);

#ifdef __cplusplus
}  // extern "C"
#endif

#endif  // KATAGO_IOS_GTP_BRIDGE_H_
