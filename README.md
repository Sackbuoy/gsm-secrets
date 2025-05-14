# getting GSM secrets in neovim
Tool for showing the value of a GSM secret
Also a lua script for adding the functionality to neovim

Authenticates to GCP with $GOOGLE_APPLICATION_CREDENTIALS env var

## Setup
1. Build go project, lua code assumes binary is available in your $PATH and is
   called `gsm`
   ```
   go build -o gsm cmd/gsm/main.go
   ```
   and place the executable in your $PATH
2. Save the `init.lua` script in `~/.config/nvim/lua/gsm-secrets/init.lua`
3. Add the following to your neovim config:
    ```
    require('gsm-secrets').setup()
    ```
