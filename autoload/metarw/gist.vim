" metarw scheme: gist
" Version: 0.0.1
" Copyright (C) 2012 emonkak <emonkak@gmail.com>
" License: MIT license  {{{
"     Permission is hereby granted, free of charge, to any person obtaining
"     a copy of this software and associated documentation files (the
"     "Software"), to deal in the Software without restriction, including
"     without limitation the rights to use, copy, modify, merge, publish,
"     distribute, sublicense, and/or sell copies of the Software, and to
"     permit persons to whom the Software is furnished to do so, subject to
"     the following conditions:
"
"     The above copyright notice and this permission notice shall be included
"     in all copies or substantial portions of the Software.
"
"     THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
"     OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
"     MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
"     IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
"     CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
"     TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
"     SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
" }}}
" Variables  "{{{1

if !exists('g:metarw_gist_user')
  let g:metarw_gist_user = system('git config --get github.user')[:-2]
endif

if !exists('g:metarw_gist_token')
  let g:metarw_gist_token = system('git config --get github.token')[:-2]
endif

let g:metarw_gist_safe_write = get(g:, 'metarw_gist_safe_write', 1)

let g:metarw_gist_public = get(g:, 'metarw_gist_public', 1)




" Interface  "{{{1
function! metarw#gist#complete(arglead, cmdline, cursorpos) abort  "{{{2
  let _ = s:parse_incomplete_fakepath(a:arglead)

  let candidates = []
  if _.gist_filename_given_p
  \  || (_.gist_id_given_p && _.given_fakepath[-1] ==# '/')
    for file in values(s:gist_metadata(_).files)
      call add(candidates,
      \        printf('%s:%s/%s/%s',
      \               _.scheme,
      \               _.gist_user,
      \               _.gist_id,
      \               file.filename))
    endfor
    let head_part = printf('%s:%s/%s/', _.scheme, _.gist_user, _.gist_id)
    let tail_part = _.gist_filename
  else
    for gist in s:gist_list(_)
      for file in values(gist.files)
        call add(candidates,
        \        printf('%s:%s/%s/%s',
        \               _.scheme,
        \               _.gist_user,
        \               gist.id,
        \               file.filename))
      endfor
    endfor
    let head_part = printf('%s:%s/', _.scheme, _.gist_user)
    let tail_part = _.gist_id
  endif

  return [candidates, head_part, tail_part]
endfunction




function! metarw#gist#read(fakepath) abort  "{{{2
  let _ = s:parse_incomplete_fakepath(a:fakepath)

  if _.gist_filename_given_p
    if _.gist_user !=# g:metarw_gist_user
      setlocal readonly
    endif
    let result = s:read_content(_)
  elseif _.gist_id_given_p
    let result = s:read_metadata(_)
  else
    let result = s:read_list(_)
  endif

  return result
endfunction




function! metarw#gist#write(fakepath, line1, line2, append_p) abort  "{{{2
  let _ = s:parse_incomplete_fakepath(a:fakepath)

  if !g:metarw_gist_safe_write || v:cmdbang
    let content = join(getline(a:line1, a:line2), "\n")
    if !_.gist_user_given_p
      return s:write_new(_, content)
    elseif _.gist_user !=# g:metarw_gist_user
      return ['error', 'Cannot write to other user''s gist']
    elseif !_.gist_filename_given_p
      return ['error', 'Filename is not given']
    else
      return s:write_update(_, content)
    endif
  endif
  return ['error', 'Trying to save changes to the gist. If you want to it, please retry with :write!']
endfunction




" Misc.  "{{{1
function! s:parse_incomplete_fakepath(incomplete_fakepath) abort  "{{{2
  let _ = {}

  let components = split(a:incomplete_fakepath, '^\l\+\zs:', !0)
  if len(components) <= 1
    echoerr 'Unexpected a:incomplete_fakepath:' string(a:incomplete_fakepath)
    throw 'metarw:gist#e1'
  endif
  let components = [components[0]] + split(components[1], '[\/]')

  let _.given_fakepath = a:incomplete_fakepath
  let _.scheme = components[0]

  " {gist_user}
  let i = 1
  if i < len(components)
    let _.gist_user_given_p = !0
    let _.gist_user = components[i]
    let i += 1
  else
    let _.gist_user_given_p = !!0
    let _.gist_user = g:metarw_gist_user
  endif

  " {gist_id}
  if i < len(components)
    let _.gist_id_given_p = !0
    let _.gist_id = components[i]
    let i += 1
  else
    let _.gist_id_given_p = !!0
    let _.gist_id = ''
  endif

  " {gist_filename}
  if i < len(components)
    let _.gist_filename_given_p = !0
    let _.gist_filename = components[i]
    let i += 1
  else
    let _.gist_filename_given_p = !!0
    let _.gist_filename = ''
  endif

  return _
endfunction




function! s:gist_metadata(_) abort  "{{{2
  let api = 'https://api.github.com/gists/' . a:_.gist_id
  let result = webapi#http#get(api, {}, {
  \   'Authorization': 'token ' . g:metarw_gist_token,
  \ })
  if result.status != 200
    throw printf('%d %s: %s', result.status, result.message, api)
  endif

  return webapi#json#decode(result.content)
endfunction




function! s:gist_list(_) abort  "{{{2
  let api = 'https://api.github.com/users/' . a:_.gist_user . '/gists'
  let result = webapi#http#get(api, {}, {
  \   'Authorization': 'token ' . g:metarw_gist_token,
  \ })
  if result.status != 200
    throw printf('%d %s: %s', result.status, result.message, api)
  endif

  return webapi#json#decode(result.content)
endfunction




function! s:read_content(_) abort  "{{{2
  let api = printf('https://gist.github.com/%s/%s/raw/%s',
  \                a:_.gist_user,
  \                a:_.gist_id,
  \                a:_.gist_filename)
  let result = webapi#http#get(api)
  if result.status != 200
    return ['error', printf('%d %s: %s', result.status, result.message, result.content)]
  endif
  put =result.content

  return ['done', '']
endfunction




function! s:read_metadata(_) abort  "{{{2
  let result = [{
  \     'label': '../',
  \     'fakepath': printf('%s:%s',
  \                        a:_.scheme,
  \                        a:_.gist_user)
  \  }]
  try
    let gist_metadata = s:gist_metadata(a:_)
  catch
    return ['error', v:exception]
  endtry
  for file in values(gist_metadata.files)
    call add(result, {
    \    'label': file.filename,
    \    'fakepath': printf('%s:%s/%s/%s',
    \                       a:_.scheme,
    \                       a:_.gist_user,
    \                       a:_.gist_id,
    \                       file.filename)
    \ })
  endfor

  return ['browse', result]
endfunction




function! s:read_list(_) abort  "{{{2
  let result = []
  try
    let gist_list = s:gist_list(a:_)
  catch
    return ['error', v:exception]
  endtry
  for gist in gist_list
    for file in values(gist.files)
      call add(result, {
      \    'label': gist.id . '/' . file.filename,
      \    'fakepath': printf('%s:%s/%s/%s',
      \                       a:_.scheme,
      \                       a:_.gist_user,
      \                       gist.id,
      \                       file.filename)
      \ })
    endfor
  endfor

  return ['browse', result]
endfunction




function! s:write_new(_, content) abort  "{{{2
  let api = 'https://api.github.com/gists'
  let result = webapi#http#post(api, webapi#json#encode({
  \   'description': expand('%:t'),
  \   'public': g:metarw_gist_public ? function('webapi#json#true') : function('webapi#json#false'),
  \   'files': {
  \     expand('%:t'): {
  \       'content': a:content
  \     }
  \   }
  \ }), {
  \   'Authorization': 'token ' . g:metarw_gist_token,
  \   'Content-Type': 'application/json',
  \   'Expect': ''
  \ })
  if result.status != 201
    return ['error', printf('%d %s: %s', result.status, result.message, result.content)]
  endif

  let gist = webapi#json#decode(result.content)
  if has_key(gist, 'html_url')
    echomsg gist.html_url
    return ['done', '']
  else
    return ['error', 'Failed to create the gist']
  endif
endfunction




function! s:write_update(_, content) abort  "{{{2
  let api = 'https://api.github.com/gists/' . a:_.gist_id
  let result = webapi#http#post(api, webapi#json#encode({
  \   'files': {
  \     a:_.gist_filename: {
  \       'content': a:content
  \     }
  \   }
  \ }), {
  \   'Authorization': 'token ' . g:metarw_gist_token,
  \   'Content-Type': 'application/json',
  \   'Expect': ''
  \ })
  if result.status != 200
    return ['error', printf('%d %s: %s', result.status, result.message, result.content)]
  endif

  let gist = webapi#json#decode(result.content)
  if has_key(gist, 'html_url')
    echomsg gist.html_url
    return ['done', '']
  else
    return ['error', 'Failed to update the gist']
  endif
endfunction




" __END__  "{{{1
" vim: foldmethod=marker
