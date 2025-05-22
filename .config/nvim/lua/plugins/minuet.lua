return {
  {
    "milanglacier/minuet-ai.nvim",
    config = function()
      require("minuet").setup {
        -- Your configuration options here
        provider = "openai_compatible",
        request_timeout = 2.5,
        throttle = 1500, -- Increase to reduce costs and avoid rate limits
        debounce = 600, -- Increase to reduce costs and avoid rate limits
        provider_options = {
          openai_compatible = {
            end_point = "https://openrouter.ai/api/v1/chat/completions",
            model = "google/gemini-2.5-flash-preview-05-20",
            name = "Gemini-2.5-Flash",
            optional = {
              max_tokens = 56,
              top_p = 0.9,
              provider = {
                -- Prioritize throughput for faster completion
                sort = "throughput",
              },
            },
          },
        },
      }
    end,
  },
  { "nvim-lua/plenary.nvim" },
  { "Saghen/blink.cmp" },
}
