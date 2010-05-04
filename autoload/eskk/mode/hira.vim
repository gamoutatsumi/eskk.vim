" vim:foldmethod=marker:fen:
scriptencoding utf-8

" See 'plugin/eskk.vim' about the license.

" Saving 'cpoptions' {{{
let s:save_cpo = &cpo
set cpo&vim
" }}}

" Variables {{{
let s:rom_to_hira = eskk#table#new('rom_to_hira')
let s:skk_dict = eskk#dictionary#new([{'path': g:eskk_dictionary, 'sorted': 0}, {'path': g:eskk_large_dictionary, 'sorted': 1}])
let s:current_henkan_result = {}
" }}}

" Functions {{{

" :help <SID>
function! s:SID() "{{{
    return matchstr(expand('<sfile>'), '<SNR>\zs\d\+\ze_SID$')
endfunction "}}}

" Callback
function! eskk#mode#hira#cb_handle_key(stash) "{{{
    return 0
endfunction "}}}


" For mode structure.
function! eskk#mode#hira#hook_fn_do_lmap() "{{{
    lmap <buffer> q <Plug>(eskk:mode:hira:to-kata)
    lmap <buffer> l <Plug>(eskk:mode:hira:to-ascii)
    lmap <buffer> L <Plug>(eskk:mode:hira:to-zenei)
endfunction "}}}


" Filter functions
function! eskk#mode#hira#filter(stash) "{{{
    let char = a:stash.char
    let henkan_phase = a:stash.buftable.get_henkan_phase()

    if henkan_phase ==# g:eskk#buftable#HENKAN_PHASE_NORMAL
        return s:filter_rom_to_hira(a:stash)
    elseif henkan_phase ==# g:eskk#buftable#HENKAN_PHASE_HENKAN
        if eskk#is_henkan_key(char)
            return s:henkan_key(a:stash)
            " Assert a:stash.buftable.get_henkan_phase() == g:eskk#buftable#HENKAN_PHASE_HENKAN_SELECT
        else
            return s:filter_rom_to_hira(a:stash)
        endif
    elseif henkan_phase ==# g:eskk#buftable#HENKAN_PHASE_HENKAN_SELECT
    else
        return eskk#default_filter(a:stash)
    endif
endfunction "}}}

function s:henkan_key(stash) "{{{
    " Change henkan phase to henkan select phase.
    call a:stash.buftable.set_henkan_phase(g:eskk#buftable#HENKAN_PHASE_HENKAN_SELECT)

    let s:current_henkan_result = s:skk_dict.refer(a:stash.buftable)

    let buf_str = a:stash.buftable.get_current_buf_str()
    call buf_str.clear_rom_str()
    call buf_str.set_filter_str(s:current_henkan_result.get_next())
endfunction "}}}

function! s:filter_rom_to_hira(stash) "{{{
    let char = a:stash.char
    let buf_str = a:stash.buftable.get_current_buf_str()
    let rom_str = buf_str.get_rom_str() . char

    call eskk#util#logf('mode hira - char = %s, rom_str = %s', string(char), string(rom_str))

    if s:rom_to_hira.has_map(rom_str)
        " Match!
        call eskk#util#logf('%s - match!', rom_str)

        " Set filtered string.
        call buf_str.push_filter_str(
        \   s:rom_to_hira.get_map_to(rom_str)
        \)
        call buf_str.clear_rom_str()

        " Set rest string.
        "
        " NOTE:
        " rest must not have multibyte string.
        " rest is for rom string.
        let rest = s:rom_to_hira.get_rest(rom_str, -1)
        " Assumption: 's:rom_to_hira.has_map(rest)' returns false here.
        if rest !=# -1
            call add(a:stash.option.redispatch_chars, rest)
        endif

        " Clear filtered string when eskk#filter_key()'s finalizing.
        let s:buftable = a:stash.buftable
        function! s:finalize()
            if s:buftable.get_henkan_phase() ==# g:eskk#buftable#HENKAN_PHASE_NORMAL
                let buf_str = s:buftable.get_current_buf_str()
                call buf_str.clear_filter_str()
            endif
        endfunction

        call add(
        \   a:stash.option.finalize_fn,
        \   eskk#util#get_local_func('finalize', s:SID())
        \)

        return

    elseif s:rom_to_hira.has_candidates(rom_str)
        " Has candidates but not match.
        call eskk#util#logf('%s - wait for a next key.', rom_str)
        call buf_str.push_rom_str(char)
        return

    else
        " No candidates.
        " Remove rom_str[-2].
        call eskk#util#logf('%s - no candidates.', rom_str)
        if strlen(rom_str) == 1
            call buf_str.clear_rom_str()
            let a:stash.option.return = rom_str
        else
            call buf_str.pop_rom_str()
            call buf_str.push_rom_str(char)
        endif
        return
    endif
endfunction "}}}

" }}}

" Restore 'cpoptions' {{{
let &cpo = s:save_cpo
" }}}
