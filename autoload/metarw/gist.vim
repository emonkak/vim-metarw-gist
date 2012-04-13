" metarw scheme: gist
" Version: 0.0.0
" Copyright (C) 2011 emonkak <emonkak@gmail.com>
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
  let s:metarw_gist_user = system('git config --global github.user')[:-2]
  if s:metarw_gist_user == ''
    let s:metarw_gist_user = $GITHUB_USER
  end
endif

if !exists('g:metarw_gist_password')
  let s:metarw_gist_password = system('git config --global github.password')[:-2]
  if s:metarw_gist_password == ''
    let s:metarw_gist_password = $GITHUB_PASSWORD
  end
endif




" Interface  "{{{1
function! metarw#gist#complete(arglead, cmdline, cursorpos)  "{{{2
  let _ = s:parse_incomplete_fakepath(a:arglead)

  let candidates = []
  if _.gist_filename_given_p
  \  || (_.gist_id_given_p && _.given_fakepath[-1] ==# '/')
    for filename in keys(s:gist_metadata(_).files)
      call add(candidates,
      \        printf('%s:%s/%s/%s',
      \               _.scheme,
      \               _.gist_user,
      \               _.gist_id,
      \               filename))
    endfor
    let head_part = printf('%s:%s/%s/', _.scheme, _.gist_user, _.gist_id)
    let tail_part = _.gist_filename
  else
    let ids = {}
    for gist in s:gist_list(_)
      if !has_key(ids, gist.id)
        call add(candidates,
        \        printf('%s:%s/%s',
        \               _.scheme,
        \               _.gist_user,
        \               gist.id)
        \ )
	  endif
      let ids[gist.id] = 1
    endfor
    let head_part = printf('%s:%s/', _.scheme, _.gist_user)
    let tail_part = _.gist_id
  endif

  return [candidates, head_part, tail_part]
endfunction




function! metarw#gist#read(fakepath)  "{{{2
  let _ = s:parse_incomplete_fakepath(a:fakepath)

  if _.gist_filename_given_p
    let result = s:read_content(_)
  elseif _.gist_id_given_p
    let result = s:read_metadata(_)
  else
    let result = s:read_list(_)
  endif

  return result
endfunction




function! metarw#gist#write(fakepath, line1, line2, append_p)  "{{{2
  let _ = s:parse_incomplete_fakepath(a:fakepath)

  let content = join(getline(a:line1, a:line2), "\n")
  if !_.gist_user_given_p
    let result = s:write_new(_, content)
  elseif s:metarw_gist_user !=# _.gist_user
    let result = ['error', 'Writing to other user gist not supported']
  elseif !_.gist_filename_given_p
    let result = ['error', 'Filename is not given']
  else
    let result = s:write_update(_, content)
  endif

  return result
endfunction




" Misc.  "{{{1
function! s:parse_incomplete_fakepath(incomplete_fakepath)  "{{{2
  let _ = {}

  let fragments = split(a:incomplete_fakepath, '^\l\+\zs:', !0)
  if len(fragments) <= 1
    echoerr 'Unexpected a:incomplete_fakepath:' string(a:incomplete_fakepath)
    throw 'metarw:gist#e1'
  endif
  let fragments = [fragments[0]] + split(fragments[1], '[\/]')

  let _.given_fakepath = a:incomplete_fakepath
  let _.scheme = fragments[0]

  " {gist_user}
  let i = 1
  if i < len(fragments)
    let _.gist_user_given_p = !0
    let _.gist_user = fragments[i]
    let i += 1
  else
    let _.gist_user_given_p = !!0
    let _.gist_user = s:metarw_gist_user
  endif

  " {gist_id}
  if i < len(fragments)
    let _.gist_id_given_p = !0
    let _.gist_id = fragments[i]
    let i += 1
  else
    let _.gist_id_given_p = !!0
    let _.gist_id = ''
  endif

  " {gist_filename}
  if i < len(fragments)
    let _.gist_filename_given_p = !0
    let _.gist_filename = fragments[i]
    let i += 1
  else
    let _.gist_filename_given_p = !!0
    let _.gist_filename = ''
  endif

  return _
endfunction




function! s:gist_metadata(_)  "{{{2
  let api = 'https://api.github.com/gists/' . a:_.gist_id
  let result = webapi#http#get(api, '', {
  \  "Authorization": printf("basic %s",
  \    webapi#base64#b64encode(s:metarw_gist_user.":".s:metarw_gist_password))
  \})
  if result.header[0] !=# 'HTTP/1.1 200 OK'
    throw 'Request failed: ' . result.header[0]
  endif

  let json = webapi#json#decode(result.content)
  if has_key(json, 'error')
    throw json.error
  endif

  return json
endfunction




function! s:gist_list(_)  "{{{2
  if a:_.gist_user == s:metarw_gist_user
    let api = 'https://api.github.com/gists'
  else
    let api = 'https://api.github.com/users/' . a:_.gist_user . '/gists'
  endif
  let result = webapi#http#get(api, '', {
  \   "Authorization": printf("basic %s",
  \     webapi#base64#b64encode(
  \       s:metarw_gist_user.":".s:metarw_gist_password))
  \ })
  if result.header[0] !=# 'HTTP/1.1 200 OK'
    throw 'Request failed: ' . result.header[0]
  endif

  if result.content ==# 'error'
    throw 'User not found'
  endif
  let json = webapi#json#decode(result.content)
  if type(json) != 3 && has_key(json, 'error')
    throw json.error
  endif

  return json
endfunction




function! s:read_content(_)  "{{{2
  try
    let gist_metadata = s:gist_metadata(a:_)
  catch
    return ['error', v:exception]
  endtry
  put =gist_metadata.files[a:_.gist_filename].content

  return ['done', '']
endfunction




function! s:read_metadata(_)  "{{{2
  let result = [{
  \     'label': '../',
  \     'fakepath': printf("%s:%s",
  \                        a:_.scheme,
  \                        a:_.gist_user)
  \  }]
  try
    let gist_metadata = s:gist_metadata(a:_)
  catch
    return ['error', v:exception]
  endtry

  for filename in keys(gist_metadata.files)
    call add(result, {
    \    "label": filename,
    \    "fakepath": printf("%s:%s/%s/%s",
    \                       a:_.scheme,
    \                       a:_.gist_user,
    \                       a:_.gist_id,
    \                       filename)
    \ })
  endfor

  return ['browse', result]
endfunction




function! s:read_list(_)  "{{{2
  let result = []
  try
    let gist_list = s:gist_list(a:_)
  catch
    return ['error', v:exception]
  endtry
  if a:_.gist_filename_given_p
    for gist in gist_list
      for filename in keys(gist.files)
        call add(result, {
        \    'label': gist.id . '/' . filename,
        \    'fakepath': printf('%s:%s/%s/%s',
        \                       a:_.scheme,
        \                       a:_.gist_user,
        \                       gist.id,
        \                       filename)
        \ })
      endfor
    endfor
  else
    let ids = {}
    for gist in gist_list
      if !has_key(ids, gist.id)
        call add(result, {
        \    'label': gist.id . '/',
        \    'fakepath': printf('%s:%s/%s/',
        \                       a:_.scheme,
        \                       a:_.gist_user,
        \                       gist.id)
        \ })
      endif
      let ids[gist.id] = 1
    endfor
  endif

  return ['browse', result]
endfunction




function! s:write_new(_, content)  "{{{2
  let api = 'https://api.github.com/gists'
  let result = webapi#http#post(api,
  \   webapi#json#encode({
  \     "files": {
  \       expand('%:t'): {
  \         "description": "",
  \         "public": "true",
  \         "content": a:content
  \       }
  \     }
  \   }), {
  \     "Authorization": printf("basic %s",
  \       webapi#base64#b64encode(
  \         s:metarw_gist_user.":".s:metarw_gist_password))
  \   }
  \ )
  if result.header[0] !=# 'HTTP/1.1 200 OK'
    return ['error', 'Request failed: ' . result.header[0]]
  endif

  let gist = webapi#json#decode(result.content)
  echo 'https://gist.github.com/' . gist.id

  return ['done', '']
endfunction




function! s:write_update(_, content)  "{{{2
  let file_ext = fnamemodify(a:_.gist_filename, ':e')

  let api = 'https://api.github.com/gists/' . a:_.gist_id
  let result = webapi#http#post(api,
  \   webapi#json#encode({
  \     "files": {
  \       a:_.gist_filename: {
  \         "content": a:content
  \       }
  \     }
  \   }), {
  \     "Authorization": printf("basic %s",
  \       webapi#base64#b64encode(
  \         s:metarw_gist_user.":".s:metarw_gist_password))
  \   }
  \ )
  if result.header[0] !=# 'HTTP/1.1 200 OK'
    return ['error', 'Request failed: ' . result.header[0]]
  endif

  return ['done', '']
endfunction




" __END__  "{{{1
" vim: foldmethod=marker
