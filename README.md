# gsm-secrets
Neovim plugin that uses $GOOGLE_APPLICATION_CREDENTIALS to authenticate to the
currently active GCP project and show the value of the GSM secret currently
highlighted

Setup assumes the `go` binary is available at your PATH

## Set up with vim-plug
```
vim.call('plug#begin', '~/.config/nvim/plugged')
  Plug('Sackbuoy/gsm-secrets')
vim.call('plug#end')

require('gsm-secrets').setup()

```
