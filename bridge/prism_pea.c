// prism_pea.c -- flat C bridge over prism's handle-based API, shaped for what mkxp-z's Win32API can
// actually call: plain global cdecl functions taking only ints and strings. The PrismContext and
// PrismBackend pointers stay INSIDE this DLL as statics, because handing a raw handle back to Ruby
// would truncate it on x64. PeaSpeak re-acquires the best backend once on failure, and prism's
// availability poll flags when a backend appears or goes away, so a screen reader started or restarted
// AFTER the game takes over from the speech engine on the next line. Build: bridge/build_prism_pea.ps1.
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdbool.h>
#include <stddef.h>
#include <string.h>
#include <prism.h>

#define PEA_API __declspec(dllexport)
#define PEA_POLL_BACKOFF_MS 4000

enum { PEA_RESELECT_NONE = 0, PEA_RESELECT_CHANGE = 1, PEA_RESELECT_BASELINE = 2 };

/* Single-threaded by assumption: mkxp-z runs game scripts on one thread, so the free-then-reassign of
 * g_backend needs no locking. Only g_reselect is written from prism's poll thread. */
static PrismContext *g_ctx = NULL;
static PrismBackend *g_backend = NULL;
static volatile LONG g_reselect = PEA_RESELECT_NONE;

/* Poll-thread callback: a backend's availability changed, so the current choice may be stale. */
static void PRISM_CALL pea_on_availability(void *userdata, PrismBackendId backend, const char *name,
                                           bool available) {
  (void)userdata;
  (void)backend;
  (void)name;
  (void)available;
  InterlockedExchange(&g_reselect, PEA_RESELECT_CHANGE);
}

/* Poll-thread callback: the first scan is done, so a reader that started between the first choice and that
 * scan is never reported as a change. */
static void PRISM_CALL pea_on_baseline(void *userdata) {
  (void)userdata;
  InterlockedCompareExchange(&g_reselect, PEA_RESELECT_BASELINE, PEA_RESELECT_NONE);
}

/* The prism context, created once with the availability poll on. */
static PrismContext *pea_context(void) {
  if (g_ctx == NULL) {
    PrismConfig cfg = prism_config_init();
    cfg.availability_callback = pea_on_availability;
    cfg.availability_baseline_callback = pea_on_baseline;
    cfg.availability_backoff_max_ms = PEA_POLL_BACKOFF_MS;
    cfg.availability_auto_power_manage = true;
    g_ctx = prism_init(&cfg);
  }
  return g_ctx;
}

static bool pea_is_screen_reader(PrismBackend *backend) {
  return (prism_backend_get_features(backend) & PRISM_BACKEND_IS_SCREEN_READER) != 0;
}

static bool pea_same_backend(PrismBackend *a, PrismBackend *b) {
  const char *na = prism_backend_name(a);
  const char *nb = prism_backend_name(b);
  return na != NULL && nb != NULL && strcmp(na, nb) == 0;
}

/* Prism's best backend, initialized, or NULL. */
static PrismBackend *pea_create_best(void) {
  PrismBackend *backend = prism_registry_create_best(g_ctx);
  if (backend == NULL) {
    return NULL;
  }
  PrismError init = prism_backend_initialize(backend);
  if (init != PRISM_OK && init != PRISM_ERROR_ALREADY_INITIALIZED) {
    prism_backend_free(backend);
    return NULL;
  }
  return backend;
}

/* Switches to prism's best backend when the poll flagged a change and the best is another one; the same
 * backend stays, so its speech is not cut. After the baseline alone, a screen reader in use is kept. */
static void pea_reselect_if_due(void) {
  if (g_ctx == NULL || g_backend == NULL) {
    return;
  }
  LONG due = InterlockedExchange(&g_reselect, PEA_RESELECT_NONE);
  if (due == PEA_RESELECT_NONE || (due == PEA_RESELECT_BASELINE && pea_is_screen_reader(g_backend))) {
    return;
  }
  PrismBackend *best = pea_create_best();
  if (best == NULL) {
    return;
  }
  if (pea_same_backend(best, g_backend)) {
    prism_backend_free(best);
    return;
  }
  prism_backend_free(g_backend);
  g_backend = best;
}

static int pea_acquire(void) {
  if (pea_context() == NULL) {
    return 0;
  }
  if (g_backend != NULL) {
    prism_backend_free(g_backend);
    g_backend = NULL;
  }
  g_backend = pea_create_best();
  return g_backend != NULL;
}

PEA_API int PeaInitialize(void) {
  if (g_backend != NULL) {
    return 1;
  }
  return pea_acquire();
}

/* Releases the backend and the prism context; idempotent. The mod never calls it: the game's process exit
 * releases everything. */
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
  pea_reselect_if_due();
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
  pea_reselect_if_due();
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
