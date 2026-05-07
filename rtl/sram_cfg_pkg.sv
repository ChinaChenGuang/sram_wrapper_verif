// ============================================================
// SRAM Configuration Package
// ============================================================
// Defines standard SRAM configurations for multi-config testing.
// Each config entry: {ADDR_WIDTH, DATA_WIDTH, description}
// ============================================================

`timescale 1ns/1ps

package sram_cfg_pkg;

    // Number of configurations in the standard set
    localparam int NUM_CFG = 6;

    // Config ID enumeration
    typedef enum int {
        CFG_256x8   = 0,   // Small:  256 depth x 8 bits
        CFG_1Kx32   = 1,   // Medium: 1K depth x 32 bits  (default)
        CFG_4Kx64   = 2,   // Large:  4K depth x 64 bits
        CFG_64x256  = 3,   // Wide:   64 depth x 256 bits
        CFG_64Kx8   = 4,   // Deep:   64K depth x 8 bits
        CFG_512x128 = 5    // Mixed:  512 depth x 128 bits
    } cfg_id_e;

    // Config descriptor struct
    typedef struct {
        int           id;
        cfg_id_e      cfg_id;
        int           addr_width;
        int           data_width;
        int           depth;
        string        name;
        string        desc;
    } sram_cfg_t;

    // Standard configuration table
    function automatic sram_cfg_t get_config(int idx);
        sram_cfg_t c;
        case (idx)
            CFG_256x8: begin
                c.cfg_id     = CFG_256x8;
                c.addr_width = 8;
                c.data_width = 8;
                c.name       = "CFG_256x8";
                c.desc       = "Small: 256x8";
            end
            CFG_1Kx32: begin
                c.cfg_id     = CFG_1Kx32;
                c.addr_width = 10;
                c.data_width = 32;
                c.name       = "CFG_1Kx32";
                c.desc       = "Medium: 1Kx32";
            end
            CFG_4Kx64: begin
                c.cfg_id     = CFG_4Kx64;
                c.addr_width = 12;
                c.data_width = 64;
                c.name       = "CFG_4Kx64";
                c.desc       = "Large: 4Kx64";
            end
            CFG_64x256: begin
                c.cfg_id     = CFG_64x256;
                c.addr_width = 6;
                c.data_width = 256;
                c.name       = "CFG_64x256";
                c.desc       = "Wide: 64x256";
            end
            CFG_64Kx8: begin
                c.cfg_id     = CFG_64Kx8;
                c.addr_width = 16;
                c.data_width = 8;
                c.name       = "CFG_64Kx8";
                c.desc       = "Deep: 64Kx8";
            end
            CFG_512x128: begin
                c.cfg_id     = CFG_512x128;
                c.addr_width = 9;
                c.data_width = 128;
                c.name       = "CFG_512x128";
                c.desc       = "Mixed: 512x128";
            end
            default: begin
                c.cfg_id     = CFG_1Kx32;
                c.addr_width = 10;
                c.data_width = 32;
                c.name       = "CFG_DEFAULT";
                c.desc       = "Default: 1Kx32";
            end
        endcase
        c.id    = idx;
        c.depth = 1 << c.addr_width;
        return c;
    endfunction

endpackage
