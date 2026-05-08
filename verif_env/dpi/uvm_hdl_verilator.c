// ============================================================
// uvm_hdl_verilator.c — Verilator stub for UVM HDL access
// ============================================================
// UVM uses HDL access for backdoor register access and path-based
// probing. Since Verilator compiles to C++, standard PLI/VPI is
// not available. All functions are stubbed to return 0/false.
// ============================================================

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>

// ------ hdl_check_path (DPI) ------
int uvm_hdl_check_path(const char *path) {
    (void)path;
    return 0;  // path not found (backdoor disabled)
}

// ------ hdl_read (DPI) ------
int uvm_hdl_read(const char *path, int lo, int hi, void *value) {
    (void)path; (void)lo; (void)hi; (void)value;
    return 0;  // fail
}

// ------ hdl_deposit (DPI) ------
int uvm_hdl_deposit(const char *path, int lo, int hi, const void *value) {
    (void)path; (void)lo; (void)hi; (void)value;
    return 0;  // fail
}

// ------ hdl_set_vlogic (DPI) ------
void uvm_hdl_set_vlogic(const char *path, int value) {
    (void)path; (void)value;
}

// ------ hdl_get_vlogic (DPI) ------
int uvm_hdl_get_vlogic(const char *path) {
    (void)path;
    return 0;
}

// ------ hdl_list_* (DPI) ------
int uvm_hdl_list_count(const char *path) {
    (void)path;
    return 0;
}

void uvm_hdl_list_value(const char *path, int idx, char *buf, int sz) {
    (void)path; (void)idx;
    if (buf && sz > 0) buf[0] = '\0';
}

int uvm_hdl_list_nets(const char *path, int idx, char *buf, int sz) {
    (void)path; (void)idx;
    if (buf && sz > 0) buf[0] = '\0';
    return 0;
}

#ifdef __cplusplus
}
#endif
