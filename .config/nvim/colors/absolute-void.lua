vim.cmd("highlight clear")
if vim.fn.exists("syntax_on") then
  vim.cmd("syntax reset")
end

vim.o.background = "dark"
vim.g.colors_name = "absolute-void"

local colors = {
  bg      = "#000000",
  fg      = "#d0d0d0",
  fg_dim  = "#8f8f8f",  
  fg_dull = "#666666",  
  white   = "#e0e0e0",  
}

local hl = vim.api.nvim_set_hl

hl(0, "Normal",     { fg = colors.fg, bg = colors.bg })
hl(0, "Comment",    { fg = colors.fg_dull, italic = true })
hl(0, "Constant",   { fg = colors.white, bold = true })
hl(0, "String",     { fg = colors.fg_dim, italic = true })
hl(0, "Identifier", { fg = colors.fg })
hl(0, "Function",   { fg = colors.white, bold = true })
hl(0, "Statement",  { fg = colors.fg, bold = true })
hl(0, "Keyword",    { fg = colors.fg, bold = true })
hl(0, "Type",       { fg = colors.fg_dim })
hl(0, "Error",      { fg = colors.fg, bold = true, underline = true })  
hl(0, "CursorLine", { bg = "#151515" })
hl(0, "LineNr",     { fg = colors.fg_dull })
hl(0, "Visual",     { bg = "#3c3836" })  
