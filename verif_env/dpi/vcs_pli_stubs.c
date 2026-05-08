// ============================================================
// vcs_pli_stubs.c — Minimal VCS PLI/VPI stubs for Verilator
// ============================================================
// UVM DPI uses VCS backend (uvm_hdl_vcs.c) when compiled with -DVCS.
// VCS PLI/VPI functions are not available in Verilator, so we stub them.
// All backdoor access returns 0/false (not found).
// ============================================================

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>
#include <stdlib.h>
#include <string.h>

// --- PLI types ---
typedef uint32_t PLI_INT32;
typedef void*    PLI_BYTE8;
typedef struct t_vpi_handle* vpiHandle;
typedef struct t_vpi_value {
    int format;
    union { char *str; int scalar; double real; void *vector; } value;
} s_vpi_value, *p_vpi_value;

enum { vpiIntVal=1, vpiStringVal=2, vpiDecStrVal=3, vpiHexStrVal=4,
       vpiBinStrVal=5, vpiOctStrVal=6, vpiRealVal=7, vpiVectorVal=8 };

// --- acc_* functions (VCS) ---
typedef void* handle;
handle acc_handle_by_name(const char *name, void *scope) { (void)name; (void)scope; return 0; }
int    acc_fetch_fullname(handle obj, char *buf, int sz) { (void)obj; if(buf&&sz>0) buf[0]=0; return 0; }
int    acc_fetch_name(handle obj, char *buf, int sz)     { (void)obj; if(buf&&sz>0) buf[0]=0; return 0; }
int    acc_object_of_type(handle obj, int type)           { (void)obj; (void)type; return 0; }
int    acc_fetch_size(handle obj)                         { (void)obj; return 0; }
int    acc_fetch_index(handle obj)                        { (void)obj; return 0; }
int    acc_fetch_range(handle obj, int *msb, int *lsb)    { (void)obj; if(msb)*msb=0; if(lsb)*lsb=0; return 0; }
handle acc_next_cell(handle net, handle ref)              { (void)net; (void)ref; return 0; }
handle acc_next_net(handle ref)                           { (void)ref; return 0; }
handle acc_next_scope(handle ref)                         { (void)ref; return 0; }
handle acc_handle_scope(handle obj)                       { (void)obj; return 0; }
handle acc_next_child(handle mod, handle child)           { (void)mod; (void)child; return 0; }
void   acc_close(handle obj)                              { (void)obj; }
void   acc_initialize(void)                               {}
int    acc_fetch_paramval(handle obj, char *buf, int sz)  { (void)obj; if(buf&&sz>0) buf[0]=0; return 0; }
void   acc_configure(int a, int b)                        { (void)a; (void)b; }

// --- tf_* functions (VCS) ---
char*  tf_getcstringp(int n)     { (void)n; return 0; }
int    tf_getp(int n)            { (void)n; return 0; }
int    tf_nump(void)             { return 0; }
int    tf_getlongp(int *a, int n) { (void)a; (void)n; return 0; }
void   tf_putp(int n, int v)     { (void)n; (void)v; }
void   tf_setworkarea(void *p)   { (void)p; }
void*  tf_getworkarea(void)      { return 0; }

// --- vpi_* functions (IEEE) ---
vpiHandle vpi_handle_by_name(const char *name, vpiHandle scope) {
    (void)name; (void)scope; return 0;
}
vpiHandle vpi_iterate(int type, vpiHandle ref)            { (void)type; (void)ref; return 0; }
vpiHandle vpi_scan(vpiHandle iter)                        { (void)iter; return 0; }
vpiHandle vpi_handle(int type, vpiHandle ref)             { (void)type; (void)ref; return 0; }
char*     vpi_get_str(int prop, vpiHandle obj)            { (void)prop; (void)obj; return 0; }
int       vpi_get(int prop, vpiHandle obj)                { (void)prop; (void)obj; return 0; }
void      vpi_get_value(vpiHandle obj, p_vpi_value val)   { (void)obj; (void)val; }
vpiHandle vpi_put_value(vpiHandle obj, p_vpi_value val, void *when, int flags) {
    (void)obj; (void)val; (void)when; (void)flags; return 0;
}
void      vpi_free_object(vpiHandle obj)                  { (void)obj; }
int       vpi_get_vlog_info(void *info)                   { (void)info; return 0; }
int       vpi_chk_error(vpiHandle *err)                   { if(err) *err=0; return 0; }
int       vpi_mcd_close(int mcd)                          { (void)mcd; return 0; }
char*     vpi_mcd_name(int mcd)                           { (void)mcd; return 0; }
int       vpi_mcd_open(char *name)                        { (void)name; return 1; }
int       vpi_mcd_printf(int mcd, char *fmt, ...)         { (void)mcd; (void)fmt; return 0; }
int       vpi_printf(char *fmt, ...)                      { (void)fmt; return 0; }
void      vpi_get_time(vpiHandle obj, void *time)         { (void)obj; (void)time; }
int       vpi_get_data(vpiHandle obj, int id, void *loc, int limit) { (void)obj; (void)id; (void)loc; (void)limit; return 0; }

// --- Additional VCS symbols ---
int snPrintAttrs(char *buf, int sz, int nargs, ...)       { (void)buf;(void)sz;(void)nargs; return 0; }
int tf_dofinish(void)                                      { return 0; }
int vcs_execution_region(void)                             { return 0; }
void vcs_atexit(void (*fn)(void))                          { (void)fn; }

#ifdef __cplusplus
}
#endif
