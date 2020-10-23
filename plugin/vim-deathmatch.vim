fun! VimDeathmatch()
    lua for k in pairs(package.loaded) do if k:match("^vim%-deathmatch") then package.loaded[k] = nil end end
    lua require("vim-deathmatch").start()
endfun

augroup VimDeathmatch
    autocmd!
    autocmd WinClosed * :lua require("vim-deathmatch").onWinClose(vim.fn.expand('<afile>'))
augroup END

