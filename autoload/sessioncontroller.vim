let s:savedIskeyword = &iskeyword

function! s:ResetAugroup() abort
    augroup au_vimcasechange
        autocmd!
    augroup END
endfunction

function! s:SetAugroup() abort
    augroup au_vimcasechange
        autocmd!
        autocmd CursorMoved * call s:OnCursorMoved()
    augroup END
endfunction

let s:sessionStarted = 0
function! s:OnCursorMoved() abort
    call s:ResetAugroup()
    let s:sessionStarted = 0
    let &iskeyword = s:savedIskeyword

    " exit visual mode
    execute "normal! \<Esc>"
endfunction

function! sessioncontroller#SessionController() abort
    if (s:sessionStarted == 0)
        let s:savedIskeyword = &iskeyword
        set iskeyword+=-
    endif

    call s:ResetAugroup()

    if (s:sessionStarted)
        undojoin
    endif

    let s:sessionStarted = 1
    call timer_start(10, { -> s:SetAugroup() })
endfunction