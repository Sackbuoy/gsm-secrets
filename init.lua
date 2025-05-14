-- save this in ~/.config/nvim/lua/gsm-secrets/init.lua
local M = {}

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
  
  -- Check if gsm tool is available
  if vim.fn.executable("gsm") ~= 1 then
    vim.notify("gsm tool not found in PATH", vim.log.levels.ERROR)
    return
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
  vim.fn.jobstart("gsm --name=" .. secret_name, {
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
function M.visual_get_secret(args)
  -- Process the visual selection then clear the marks
  M.get_secret()
end

-- Set up the plugin
function M.setup()
  -- Create commands
  vim.api.nvim_create_user_command("GSMSecret", function(opts)
    M.get_secret()
  end, {range = true})
end

return M
