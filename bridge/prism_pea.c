// prism_pea.c -- flat C bridge over prism's handle-based API, shaped for what mkxp-z's Win32API can
// actually call: plain global cdecl functions taking only ints and strings. The PrismContext and
// PrismBackend pointers stay INSIDE this DLL as statics, because handing a raw handle back to Ruby
// would truncate it on x64. PeaSpeak re-acquires the best backend once on failure, so a reader started
// AFTER the game picks up on the next line. Build: bridge/build_prism_pea.ps1.
#include <stdbool.h>
#include <stddef.h>
#include <prism.h>

#define PEA_API __declspec(dllexport)

/* Single-threaded by assumption: mkxp-z runs game scripts on one thread, so the free-then-reassign of
 * g_backend in pea_acquire needs no locking. Revisit if a host ever calls from two threads. */
static PrismContext *g_ctx = NULL;
static PrismBackend *g_backend = NULL;

static int pea_acquire(void) {
  if (g_ctx == NULL) {
    g_ctx = prism_init(NULL);
  }
  if (g_ctx == NULL) {
    return 0;
  }
  if (g_backend != NULL) {
    prism_backend_free(g_backend);
    g_backend = NULL;
  }
  g_backend = prism_registry_create_best(g_ctx);
  if (g_backend == NULL) {
    return 0;
  }
  PrismError init = prism_backend_initialize(g_backend);
  if (init != PRISM_OK && init != PRISM_ERROR_ALREADY_INITIALIZED) {
    prism_backend_free(g_backend);
    g_backend = NULL;
    return 0;
  }
  return 1;
}

PEA_API int PeaInitialize(void) {
  if (g_backend != NULL) {
    return 1;
  }
  return pea_acquire();
}

/* The teardown half of PeaInitialize, exported for symmetry and for any host that has to release prism
 * inside a process that keeps running. The MOD never calls it, and that is a decision, not an oversight:
 * there is no teardown point to call it from. The game ends by the process dying, so Windows unloads this
 * DLL and reclaims the backend, its COM apartment and every handle -- and tearing a speech backend down
 * while the loader is already unwinding is riskier than letting the OS do it. The two events that look
 * like teardown are not: the mod's enable/disable toggle is a RECONNECT gesture (it re-inits, it never
 * releases), and a script reload leaves this DLL loaded, so PeaInitialize finds g_backend alive and
 * returns at once. Idempotent and safe to call twice, for the host that does want it. */
PEA_API void PeaShutdown(void) {
  if (g_backend != NULL) {
    prism_backend_free(g_backend);
    g_backend = NULL;
  }
  if (g_ctx != NULL) {
    prism_shutdown(g_ctx);
    g_ctx = NULL;
  }
}

PEA_API int PeaSpeak(const char *text, int interrupt) {
  if (text == NULL) {
    return 0;
  }
  if (g_backend == NULL && !pea_acquire()) {
    return 0;
  }
  if (prism_backend_speak(g_backend, text, interrupt != 0) == PRISM_OK) {
    return 1;
  }
  if (!pea_acquire()) {
    return 0;
  }
  return prism_backend_speak(g_backend, text, interrupt != 0) == PRISM_OK ? 1 : 0;
}

PEA_API int PeaBraille(const char *text) {
  if (text == NULL) {
    return 0;
  }
  if (g_backend == NULL && !pea_acquire()) {
    return 0;
  }
  if (prism_backend_braille(g_backend, text) == PRISM_OK) {
    return 1;
  }
  if (!pea_acquire()) {
    return 0;
  }
  return prism_backend_braille(g_backend, text) == PRISM_OK ? 1 : 0;
}

PEA_API int PeaStop(void) {
  return (g_backend != NULL && prism_backend_stop(g_backend) == PRISM_OK) ? 1 : 0;
}

PEA_API int PeaPause(void) {
  return (g_backend != NULL && prism_backend_pause(g_backend) == PRISM_OK) ? 1 : 0;
}

PEA_API int PeaResume(void) {
  return (g_backend != NULL && prism_backend_resume(g_backend) == PRISM_OK) ? 1 : 0;
}

PEA_API int PeaIsSpeaking(void) {
  bool speaking = false;
  if (g_backend == NULL) {
    return -1;
  }
  if (prism_backend_is_speaking(g_backend, &speaking) != PRISM_OK) {
    return -1;
  }
  return speaking ? 1 : 0;
}

PEA_API const char *PeaBackendName(void) {
  const char *name = (g_backend != NULL) ? prism_backend_name(g_backend) : NULL;
  return name != NULL ? name : "";
}
