|-----|---------------------------|---------------|-----|---------------------------|----------------|
| 1P  |                           |               | 2P  |                           |                |
|-----|---------------------------|---------------|-----|---------------------------|----------------|
| I/O | Name                      | Description   | I/O | Name                      | Description    |
|-----|---------------------------|---------------|-----|---------------------------|----------------|
| I   | `WEB                    ` | 读/写 使能    | I   | `BWEB                   ` | bit write使能  |
| I   | `BWEB                   ` | bit write使能 | I   | `WEB                    ` | 写使能, 低有效 |
| I   | `CEB                    ` | 芯片使能      | I   | `REB                    ` | 读使能, 低有效 |
| I   | `D                      ` | 数据输入      | I   | `D                      ` | 数据输入       |
| I   | `A                      ` | 地址          | I   | `AA                     ` | 写地址         |
| O   | `Q                      ` | 数据输出      | I   | `AB                     ` | 读地址         |
| I   | `CLK                    ` | 时钟          | O   | `Q                      ` | 数据输出       |
| I   | `mem_cfg                ` | 测试配置      | I   | `CLKW                   ` | 写时钟         |
| I   | `rstn                   ` | pipe复位      | I   | `CLKR                   ` | 读时钟         |
| O   | `ecc_encoder_parity_out ` | ecc           | I   | `mem_cfg                ` | 测试配置       |
| O   | `ecc_decoder_parity_out ` | ecc           | I   | `RSTNW                  ` | pipe复位       |
| O   | `ecc_error_type         ` | ecc           | I   | `RSTNR                  ` | pipe复位       |
| O   | `latent_err             ` | ecc           | O   | `ecc_encoder_parity_out ` | ecc            |
| O   | `mission_err            ` | ecc           | O   | `ecc_decoder_parity_out ` | ecc            |
| I   | `ecc_encoder_bypass     ` | ecc           | O   | `ecc_error_type         ` | ecc            |
| I   | `ecc_encoder_parity_in  ` | ecc           | O   | `latent_err             ` | ecc            |
| I   | `ecc_decoder_bypass     ` | ecc           | O   | `mission_err            ` | ecc            |
| I   | `fault_injection_enable ` | ecc           | I   | `ecc_encoder_bypass     ` | ecc            |
| I   | `fault_injection_value  ` | ecc           | I   | `ecc_encoder_parity_in  ` | ecc            |
|     |                           |               | I   | `ecc_decoder_bypass     ` | ecc            |
|     |                           |               | I   | `fault_injection_enable ` | ecc            |
|     |                           |               | I   | `fault_injection_value  ` | ecc            |
