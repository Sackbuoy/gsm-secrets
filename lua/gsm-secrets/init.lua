local M = {}

-- Function to build and install the Go binary
local function build_gsm_tool()
  -- Path to store the compiled binary
  local plugin_dir = vim.fn.stdpath("data") .. "/gsm-secrets"
  local bin_dir = plugin_dir .. "/bin"
  
  -- Create directories if they don't exist
  vim.fn.mkdir(plugin_dir, "p")
  vim.fn.mkdir(bin_dir, "p")
  
  -- Find the plugin source directory
  local plugin_source_dir = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h:h")
  
  -- Build the Go project
  vim.notify("Building GSM tool...", vim.log.levels.INFO)
  
  -- Change to the plugin source directory to access go.mod
  local old_dir = vim.fn.getcwd()
  vim.fn.chdir(plugin_source_dir)
  
  -- Build the binary
  local build_cmd = "go build -mod=vendor -o " .. bin_dir .. "/gsm ./lua/gsm-secrets"
  local build_result = vim.fn.system(build_cmd)
  
  -- Return to the original directory
  vim.fn.chdir(old_dir)
  
  if vim.v.shell_error ~= 0 then
    vim.notify("Failed to build GSM tool: " .. build_result, vim.log.levels.ERROR)
    return false
  end
  
  vim.notify("GSM tool built successfully at " .. bin_dir .. "/gsm", vim.log.levels.INFO)
  return true
end

-- Get path to the GSM binary
local function get_gsm_path()
  -- Try to find in PATH first
  if vim.fn.executable("gsm") == 1 then
    return "gsm"
  end
  
  -- Check our plugin's bin directory
  local bin_path = vim.fn.stdpath("data") .. "/gsm-secrets/bin/gsm"
  if vim.fn.filereadable(bin_path) == 1 then
    return bin_path
  end
  
  -- Not found anywhere
  return nil
end

-- Function to get the selected text in visual mode
local function get_visual_selection()
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  local lines = vim.fn.getline(start_pos[2], end_pos[2])
  
  if #lines == 0 then
    return ""
  end
  
  -- Adjust the last line to only include selected portion
  if #lines > 0 then
    local end_col = end_pos[3]
    if end_col == 2147483647 then
      end_col = #lines[#lines] -- Use the whole line if end_col is max value
    end
    lines[#lines] = string.sub(lines[#lines], 1, end_col)
    
    -- Adjust first line to only include selected portion
    lines[1] = string.sub(lines[1], start_pos[3], #lines[1])
  end
  
  return table.concat(lines, "\n")
end

-- Function to get secret value and copy to clipboard
function M.get_secret()
  -- Get the selected text
  local secret_name = get_visual_selection()
  
  if secret_name == "" then
    vim.notify("No text selected", vim.log.levels.ERROR)
    return
  end
  
  -- Clean up the secret name (remove whitespace)
  secret_name = string.gsub(secret_name, "%s+", "")
  
  -- Get path to GSM tool
  local gsm_path = get_gsm_path()
  if not gsm_path then
    vim.notify("GSM tool not found. Trying to build it now...", vim.log.levels.WARN)
    if not build_gsm_tool() then
      vim.notify("Failed to build GSM tool. Please check your Go installation.", vim.log.levels.ERROR)
      return
    end
    gsm_path = get_gsm_path()
    if not gsm_path then
      vim.notify("GSM tool not found after build. Something went wrong.", vim.log.levels.ERROR)
      return
    end
  end
  
  -- Create a temporary output buffer
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, "GSM Secret: " .. secret_name)
  
  -- Open buffer in a floating window
  local width = 80
  local height = 20
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    col = math.floor((vim.o.columns - width) / 2),
    row = math.floor((vim.o.lines - height) / 2),
    style = "minimal",
    border = "rounded"
  })
  
  -- Set buffer options
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(buf, "filetype", "secret")
  
  -- Set initial content
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {"Loading secret: " .. secret_name .. "..."})
  
  -- Run the command in the background
  vim.fn.jobstart(gsm_path .. " --name=" .. secret_name, {
    stdout_buffered = true,
    on_stdout = function(_, data, _)
      if data then
        -- Update buffer with secret value
        vim.schedule(function()
          vim.api.nvim_buf_set_lines(buf, 0, -1, false, data)
          
          -- Copy to clipboard
          local secret_value = table.concat(data, "\n")
          vim.fn.setreg("+", secret_value)
          vim.notify("Secret copied to clipboard", vim.log.levels.INFO)
        end)
      end
    end,
    on_stderr = function(_, data, _)
      if data and #data > 1 then
        vim.schedule(function()
          vim.api.nvim_buf_set_lines(buf, 0, -1, false, {"Error:", ""})
          vim.api.nvim_buf_set_lines(buf, 2, 2, false, data)
        end)
      end
    end,
    on_exit = function(_, code, _)
      if code ~= 0 then
        vim.schedule(function()
          vim.api.nvim_buf_set_lines(buf, 0, 0, false, {"Failed to retrieve secret (exit code " .. code .. ")"})
        end)
      end
    end
  })
  
  -- Add key mappings to close the window
  vim.api.nvim_buf_set_keymap(buf, "n", "q", ":q<CR>", {noremap = true, silent = true})
  vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", ":q<CR>", {noremap = true, silent = true})
end

-- Function that runs after visual selection to get the secret
function M.visual_get_secret()
  -- Process the visual selection then clear the marks
  M.get_secret()
end

-- Set up the plugin
function M.setup()
  -- Check if the GSM tool exists, if not, build it
  if get_gsm_path() == nil then
    vim.notify("GSM tool not found. Building it now...", vim.log.levels.INFO)
    build_gsm_tool()
  end
  
  -- Create commands
  vim.api.nvim_create_user_command("GSMSecret", function(opts)
    M.get_secret()
  end, {range = true})
  
  -- Add key mappings for visual mode
  vim.api.nvim_set_keymap("x", "<Leader>gs", ":<C-u>lua require('gsm-secrets').visual_get_secret()<CR>", {noremap = true, silent = true})
end

return M
