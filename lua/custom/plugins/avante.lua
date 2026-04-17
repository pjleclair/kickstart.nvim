-- Avante is used for LLM CLI agents
--
-- Helper function to generate the tool's execution logic.
-- This encapsulates all the repetitive curl/JSON/error-handling logic.
local function create_browser_tool_func(endpoint, method, success_handler)
  -- The default way to handle a successful response.
  local default_success_handler = function(response) return 'Success: ' .. (response.message or 'Action completed.') end

  -- Use the custom handler if provided, otherwise use the default.
  local handler = success_handler or default_success_handler

  -- This is the actual function that Avante will call for the tool.
  return function(params)
    local cmd_string
    if method == 'POST' then
      local json_payload = vim.fn.json_encode(params)
      -- Build a single, shell-safe command string for POST requests
      cmd_string = 'curl -s -X POST http://localhost:3001/' .. endpoint .. " -H 'Content-Type: application/json' -d '" .. json_payload:gsub("'", "'\\''") .. "'"
    else -- Assumes GET
      cmd_string = 'curl -s -X GET http://localhost:3001/' .. endpoint
    end

    -- The core execution and response handling logic, now in one place.
    local result = vim.system({ 'sh', '-c', cmd_string }, { text = true }):wait()
    if result.code ~= 0 then return 'Network Error. Command failed with code ' .. result.code .. '. Stderr: ' .. (result.stderr or 'none') end

    local ok, response = pcall(vim.fn.json_decode, result.stdout)
    if not ok or type(response) ~= 'table' then return 'Error: Received invalid JSON from browser server: ' .. result.stdout end

    if response.success then
      return handler(response) -- Use the chosen handler for success
    else
      return 'Browser Error: ' .. (response.error or 'Unknown error.')
    end
  end
end

---@module 'lazy'
---@type LazySpec
return {
  'yetone/avante.nvim',
  build = 'make',
  event = 'VeryLazy',
  version = false, -- never set this value to "*"! never!
  opts = {
    instructions_file = 'agents.md',
    input = {
      provider = 'snacks',
      provider_opts = {
        -- additional snacks.input options
        title = 'avante input',
        icon = ' ',
      },
    },
    windows = {
      width = 40,
    },
    mode = 'agentic',
    behaviour = {
      auto_apply_diff_after_generation = false,
      auto_approve_tool_permissions = false,
      auto_suggestions = true,
    },
    shortcuts = {
      {
        name = 'refactor',
        description = 'refactor code with best practices',
        details = 'automatically refactor code to improve readability, maintainability, and follow best practices while preserving functionality',
        prompt = 'please refactor this code following best practices, improving readability and maintainability while preserving functionality.',
      },
      {
        name = 'test',
        description = 'generate unit tests',
        details = 'create comprehensive unit tests covering edge cases, error scenarios, and various input conditions',
        prompt = 'please generate comprehensive unit tests for this code, covering edge cases and error scenarios.',
      },
      -- add more custom shortcuts...
    },
    provider = 'gemini_pro',
    auto_suggestions_provider = 'gemini_flash',
    custom_tools = {
      {
        name = 'browser_goto',
        description = 'Navigates the browser to a specified URL.',
        param = { type = 'table', fields = { { name = 'url', type = 'string' } } },
        func = create_browser_tool_func('goto', 'POST'), -- No custom handler needed
      },
      {
        name = 'browser_click',
        description = 'Clicks an element on the page using a CSS selector.',
        param = { type = 'table', fields = { { name = 'selector', type = 'string' } } },
        func = create_browser_tool_func('click', 'POST'), -- No custom handler needed
      },
      {
        name = 'browser_type',
        description = 'Types text into an input field.',
        param = { type = 'table', fields = { { name = 'selector', type = 'string' }, { name = 'text', type = 'string' } } },
        func = create_browser_tool_func('type', 'POST'), -- No custom handler needed
      },
      {
        name = 'browser_scrape_text',
        description = 'Reads and returns the clean text content of the current webpage.',
        param = { type = 'table', fields = {} },
        -- This tool needs a special success handler to return the page content.
        func = create_browser_tool_func('scrape', 'GET', function(response) return response.content or '' end),
      },
      {
        name = 'browser_get_console_errors',
        description = 'Retrieves and returns a list of any JavaScript console warnings or errors.',
        param = { type = 'table', fields = {} },
        -- This tool needs a special handler to format the errors array as a string.
        func = create_browser_tool_func('errors', 'GET', function(response) return vim.fn.json_encode(response.errors) or '[]' end),
      },
    },
    providers = {
      gpt = {
        __inherited_from = 'openai',
        endpoint = 'https://10.0.24.16:4000',
        api_key_name = 'LITELLM_API_KEY',
        model = 'gpt-4.1',
      },
      gptmini = {
        __inherited_from = 'openai',
        endpoint = 'https://10.0.24.16:4000',
        api_key_name = 'LITELLM_API_KEY',
        model = 'gpt-4.1-mini',
      },
      gemini_flash = {
        __inherited_from = 'openai',
        endpoint = 'https://10.0.24.16:4000',
        api_key_name = 'LITELLM_API_KEY',
        model = 'gemini-2.5-flash',
      },
      gemini_pro = {
        __inherited_from = 'openai',
        endpoint = 'https://10.0.24.16:4000',
        api_key_name = 'LITELLM_API_KEY',
        model = 'gemini-2.5-pro',
      },
    },
  },
  dependencies = {
    'nvim-lua/plenary.nvim',
    'muniftanjim/nui.nvim',
    --- the below dependencies are optional,
    'nvim-mini/mini.pick', -- for file_selector provider mini.pick
    'nvim-telescope/telescope.nvim', -- for file_selector provider telescope
    'hrsh7th/nvim-cmp', -- autocompletion for avante commands and mentions
    'ibhagwan/fzf-lua', -- for file_selector provider fzf
    'stevearc/dressing.nvim', -- for input provider dressing
    'folke/snacks.nvim', -- for input provider snacks
    'nvim-tree/nvim-web-devicons', -- or echasnovski/mini.icons
    'zbirenbaum/copilot.lua', -- for providers='copilot'
    {
      -- support for image pasting
      'hakonharnes/img-clip.nvim',
      event = 'VeryLazy',
      opts = {
        -- recommended settings
        default = {
          embed_image_as_base64 = false,
          prompt_for_file_name = false,
          drag_and_drop = {
            insert_mode = true,
          },
          -- required for windows users
          use_absolute_path = true,
        },
      },
    },
    {
      -- make sure to set this up properly if you have lazy=true
      'meanderingprogrammer/render-markdown.nvim',
      opts = {
        file_types = { 'markdown', 'avante' },
      },
      ft = { 'markdown', 'avante' },
    },
  },
}
