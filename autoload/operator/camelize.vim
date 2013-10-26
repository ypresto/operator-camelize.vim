" vim:foldmethod=marker:fen:
scriptencoding utf-8

" Saving 'cpoptions' {{{
let s:save_cpo = &cpo
set cpo&vim
" }}}



function! operator#camelize#load() "{{{
    runtime! plugin/operator/camelize.vim
endfunction "}}}



" Utilities
function! s:map_text_with_regex(text, funcname, regex) "{{{
    let text = a:text
    let context = {
    \   'converted': '',
    \   'match': '',
    \}
    while text != ''
        let offset = match(text, a:regex)
        if offset ==# -1
            break
        endif
        let len = matchend(text, a:regex)

        let left          = offset == 0 ? '' : text[: offset - 1]
        let context.match = text[offset : offset + len - 1]
        let right         = text[offset + len :]

        let context.converted .= left . {a:funcname}(context)
        let text = right
    endwhile
    return context.converted . text
endfunction "}}}

" Utilities for operator
function! s:yank_range(motion_wiseness) "{{{
    " Select previously-selected range in visual mode.
    " NOTE: `normal! gv` does not work
    " when user uses operator from normal mode.

    " From http://gist.github.com/356290
    " But specialized to operator-user.

    try
        " For saving &selection. See :help :map-operator
        let sel_save = &l:selection
        let &l:selection = "inclusive"
        " Save @@.
        let reg_save     = getreg('z', 1)
        let regtype_save = getregtype('z')

        if a:motion_wiseness == 'char'
            let ex = '`[v`]"zy'
        elseif a:motion_wiseness == 'line'
            let ex = '`[V`]"zy'
        elseif a:motion_wiseness == 'block'
            let ex = '`[' . "\<C-v>" . '`]"zy'
        else
            " silent execute 'normal! `<' . a:motion_wiseness . '`>'
            echoerr 'internal error, sorry: this block never be reached'
        endif
        execute 'silent normal!' ex
        return @z
    finally
        let &l:selection = sel_save
        call setreg('z', reg_save, regtype_save)
    endtry
endfunction "}}}
function! s:paste_range(motion_wiseness, text) "{{{
    let reg_z_save     = getreg('z', 1)
    let regtype_z_save = getregtype('z')

    try
        call setreg('z', a:text,
        \   operator#user#visual_command_from_wise_name(a:motion_wiseness))
        silent normal! gv"zp
    finally
        call setreg('z', reg_z_save, regtype_z_save)
    endtry
endfunction "}}}
function! s:replace_range(funcname, pattern, motion_wiseness) "{{{
    " Yank the text in the range given by a:motion_wiseness.
    let text = s:yank_range(a:motion_wiseness)
    " Convert the text.
    let text = s:map_text_with_regex(text, a:funcname, a:pattern)
    " Paste the text to the range.
    call s:paste_range(a:motion_wiseness, text)
endfunction "}}}

" Internal
function! s:_split_prefix(a:word) "{{{
    let prefix_len = matchend(a:word, '^_*')
    return [word[:prefix_len], word[prefix_len:]]
endfunction "}}}

" For a atom
" e.g.: context == '_snake' => 'Snake'
"       context == 'snake'  => 'snake'
function! s:lower_camelize_atom(context) "{{{
    if a:context.match[0] != '_'
        return tolower(a:context.match)
    endif
    let word = a:context.match[0] == '_' ? a:context.match[1:] : a:context.match
    return toupper(word[0]) . tolower(word[1:])
endfunction "}}}

" For a atom
" e.g.: 'snake' => 'Snake'
function! s:upper_camelize_atom(context) "{{{
    let word = a:context.match[0] == '_' ? a:context.match[1:] : a:context.match
    return toupper(word[0]) . tolower(word[1:])
endfunction "}}}

" For a word
" e.g.: 'snake_case' => 'snakeCase'
function! s:lower_camelize_word(context) "{{{
    return s:_camelize_word(a:context, 'lower')
endfunction "}}}

" For a word
" e.g.: 'snake_case' => 'SnakeCase'
function! s:upper_camelize_word(context) "{{{
    return s:_camelize_word(a:context, 'upper')
endfunction "}}}

function! s:_camelize_word(context, word_case) "{{{
    " NOTE: Nested sub-replace-expression can't work...omg
    " (:help sub-replace-expression)
    "
    " return substitute(tolower(a:context.match), '^[a-z]\|_\zs[a-z]'.'\C', '\=toupper(submatch(0))', 'g')

    let split_word = s:_split_prefix(a:context.match)
    let prefix = split_word[0]
    let word = split_word[1]

    if word =~# '^[A-Z_]\+$'
        let action = g:operator_camelize_all_uppercase_action
        if action ==# 'nop'
            " "WORD" => "WORD"
            return prefix . word
        elseif action ==# 'lowercase'
            " "WORD" => "word"
            return prefix . tolower(word)
        elseif action ==# 'camelize'
            " "WORD" => "Word"
            return prefix . toupper(word[0]) . tolower(word[1:])
        else
            echohl WarningMsg
            echomsg "g:operator_camelize_all_uppercase_action is invalid value '"
            \       . g:operator_camelize_all_uppercase_action . "'."
            echohl None
        endif
    endif

    if a:word_case == 'lower'
        let atom_camelizer = 's:lower_camelize_atom'
    elseif a:word_case == 'upper'
        let atom_camelizer = 's:upper_camelize_atom'
    endif

    return prefix . s:map_text_with_regex(
    \   word,
    \   atom_camelizer,
    \   '\<[a-zA-Z0-9]\+\|_[a-zA-Z0-9]\+'.'\C'
    \)
endfunction "}}}

" For <Plug>(operator-camelize)
function! operator#camelize#op_camelize(motion_wiseness) "{{{
    if g:operator_camelize_word_case == 'lower'
        call s:replace_range('s:lower_camelize_word', '\w\+', a:motion_wiseness)
    elseif g:operator_camelize_word_case == 'upper'
        call s:replace_range('s:upper_camelize_word', '\w\+', a:motion_wiseness)
    else
        echohl WarningMsg
        echomsg "g:operator_camelize_word_case is invalid value '"
        \       . g:operator_camelize_word_case . "'."
        echohl None
    endif
endfunction "}}}

" For <Plug>(operator-lower-camelize)
function! operator#camelize#op_lower_camelize(motion_wiseness) "{{{
    call s:replace_range('s:lower_camelize_word', '\w\+', a:motion_wiseness)
endfunction "}}}

" For <Plug>(operator-upper-camelize)
function! operator#camelize#op_upper_camelize(motion_wiseness) "{{{
    call s:replace_range('s:upper_camelize_word', '\w\+', a:motion_wiseness)
endfunction "}}}


" For a atom
" e.g.: 'Snake' => 'snake'
function! s:decamelize_atom(context) "{{{
    return (a:context.converted ==# '' ? '' : '_')
    \       . tolower(a:context.match)
endfunction "}}}

" For a word
" e.g.: 'SnakeCase' => 'snake_case'
function! s:decamelize_word(context) "{{{
    " NOTE: Nested sub-replace-expression can't work...omg
    " (:help sub-replace-expression)
    "
    " return substitute(a:context.match, '^[A-Z]\|[a-z]\zs[A-Z]'.'\C', '\='_' . tolower(submatch(0))', 'g')

    let split_word = s:_split_prefix(a:context.match)
    let prefix = split_word[0]
    let word = split_word[1]

    if word =~# '^[A-Z_]\+$'
        let action = g:operator_decamelize_all_uppercase_action
        if action ==# 'nop'
            " "WORD" => "WORD"
            return prefix . word
        elseif action ==# 'lowercase'
            " "WORD" => "word"
            return prefix . tolower(word)
        else
            echohl WarningMsg
            echomsg "g:operator_decamelize_all_uppercase_action is invalid value '"
            \       . g:operator_decamelize_all_uppercase_action . "'."
            echohl None
        endif
    endif

    return prefix . s:map_text_with_regex(
    \   word,
    \   's:decamelize_atom',
    \   '^[a-z0-9]\+\ze[A-Z]\|^[A-Z][a-z0-9]*'.'\C',
    \)
endfunction "}}}

" For <Plug>(operator-decamelize)
function! operator#camelize#op_decamelize(motion_wiseness) "{{{
    call s:replace_range('s:decamelize_word', '\w\+', a:motion_wiseness)
endfunction "}}}



" Returns true when a:word is camelized.
" Returns false otherwise.
" e.g.: 'CamelCase' => true
" e.g.: 'camelCase' => true
" e.g.: 'snake_case' => false
" e.g.: 'camelCase_' => false
" e.g.: 'CamelCase_' => false
" e.g.: 'vim' => false
function! operator#camelize#is_camelized(word) "{{{
    " upper camel case: e.g., 'CamelCase'
    if a:word =~# '^[A-Z][A-Za-z0-9]\+$' | return 1 | endif
    " lower camel case: e.g., 'camelCase'
    if a:word =~# '^[a-z][A-Za-z0-9]*[A-Z]\+[A-Za-z0-9]*$' | return 1 | endif
    return 0
endfunction "}}}

" For a word
" e.g.: 'SnakeCase' => 'snake_case'
" e.g.: 'snake_case' => 'SnakeCase'
function! s:toggle_word(context) "{{{
    let camelized = g:operator_camelize_detect_function
    if {camelized}(a:context.match)
        return s:decamelize_word(a:context)
    else
        if g:operator_camelize_word_case == 'lower'
            return s:lower_camelize_word(a:context)
        elseif g:operator_camelize_word_case == 'upper'
            return s:upper_camelize_word(a:context)
        else
            echohl WarningMsg
            echomsg "g:operator_camelize_word_case is invalid value '"
            \       . g:operator_camelize_word_case . "'."
            echohl None
        endif
    endif
endfunction "}}}

" For <Plug>(operator-camelize-toggle)
function! operator#camelize#op_camelize_toggle(motion_wiseness) "{{{
    call s:replace_range('s:toggle_word', '\w\+', a:motion_wiseness)
endfunction "}}}



" Restore 'cpoptions' {{{
let &cpo = s:save_cpo
" }}}
