// ============================================================
// uvm_dpi_verilator.c — Complete UVM DPI stubs for Verilator
// ============================================================
// Provides all UVM DPI functions required by uvm_pkg.
// Based on UVM 1800.2, with Verilator-safe implementations.
// ============================================================

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <regex.h>     // POSIX regex (available on Linux)

// ============================================================
// HDL Access (backdoor — not supported in Verilator, return 0)
// ============================================================
int uvm_hdl_check_path(const char *path)       { (void)path; return 0; }
int uvm_hdl_read(const char *p, int l, int h, void *v) { (void)p;(void)l;(void)h;(void)v; return 0; }
int uvm_hdl_deposit(const char *p, int l, int h, const void *v) { (void)p;(void)l;(void)h;(void)v; return 0; }
void uvm_hdl_set_vlogic(const char *p, int v)  { (void)p;(void)v; }
int  uvm_hdl_get_vlogic(const char *p)         { (void)p; return 0; }
int  uvm_hdl_list_count(const char *p)         { (void)p; return 0; }
void uvm_hdl_list_value(const char *p, int i, char *b, int s) { (void)p;(void)i; if(b&&s>0) b[0]=0; }
int  uvm_hdl_list_nets(const char *p, int i, char *b, int s)  { (void)p;(void)i; if(b&&s>0) b[0]=0; return 0; }
void uvm_hdl_release(int key)                                   { (void)key; }

// ============================================================
// SV Command DPI
// ============================================================
int uvm_svcmd_dpi_execute_command(const char* cmd, char* result, int result_sz) {
    (void)cmd;
    if (result && result_sz > 0) result[0] = '\0';
    return 0;
}
const char *uvm_dpi_get_next_arg_c (int init) {
    (void)init;
    return 0;  // no more args
}

// ============================================================
// Common / Utility
// ============================================================
int uvm_common_init(void) { return 0; }

// ============================================================
// Regex (using POSIX regex.h)
// ============================================================
typedef regex_t uvm_regex_t;

static char uvm_re_buffer_buf[4096];
char* uvm_re_buffer(void) {
    return uvm_re_buffer_buf;
}

const char* uvm_re_deglobbed(const char *glob, unsigned char with_brackets) {
    (void)glob; (void)with_brackets;
    return glob;  // simple pass-through
}

void uvm_re_free(uvm_regex_t* handle) {
    if (handle) {
        regfree(handle);
        free(handle);
    }
}

uvm_regex_t* uvm_re_comp(const char* re, unsigned char deglob) {
    (void)deglob;
    uvm_regex_t *rx = (uvm_regex_t*)malloc(sizeof(uvm_regex_t));
    if (!rx) return 0;
    int rc = regcomp(rx, re, REG_EXTENDED | REG_NOSUB);
    if (rc != 0) {
        free(rx);
        return 0;
    }
    return rx;
}

int uvm_re_exec(uvm_regex_t* rexp, const char *str) {
    if (!rexp || !str) return 0;
    return (regexec(rexp, str, 0, 0, 0) == 0) ? 1 : 0;
}

uvm_regex_t* uvm_re_compexec(const char* re, const char* str,
                              unsigned char deglob, int* exec_ret) {
    int ret = 0;
    uvm_regex_t *rx = uvm_re_comp(re, deglob);
    if (rx) {
        ret = uvm_re_exec(rx, str);
    }
    if (exec_ret) *exec_ret = ret;
    return rx;
}

void uvm_re_compexecfree(const char* re, const char* str,
                          unsigned char deglob, int* exec_ret,
                          unsigned char* free_needed) {
    uvm_regex_t *rx = uvm_re_compexec(re, str, deglob, exec_ret);
    if (free_needed) *free_needed = (rx != 0);
    if (rx) uvm_re_free(rx);
}

// ============================================================
// Tool Info
// ============================================================
static char tool_name[] = "Verilator";
static char tool_ver[]  = "5.x";
char* uvm_dpi_get_tool_name_c(void)    { return tool_name; }
char* uvm_dpi_get_tool_version_c(void) { return tool_ver; }
void uvm_hdl_polling_init(void) {}
void uvm_hdl_polling_cleanup(void) {}
void uvm_hdl_polling_check(void) {}
int  uvm_hdl_polling_enabled(void) { return 0; }

#ifdef __cplusplus
}
#endif
