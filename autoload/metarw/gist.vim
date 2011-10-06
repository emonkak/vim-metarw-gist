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
" Interface  "{{{1
function! metarw#gist#complete(arglead, cmdline, cursorpos)  "{{{2
  let _ = s:parse_incomplete_fakepath(a:arglead)

  let candidates = []
  if _.id_given_p
    for filename in s:gist_metadata(_).gists[0].files
      call add(candidates,
      \        printf('%s:%s/%s/%s',
      \                _.scheme,
      \                _.gist_user,
      \                _.gist_id,
      \                filename))
    endfor
    let head_part = printf('%s:%s/%s/', _.scheme, _.gist_user, _.gist_id)
    let tail_part = _.gist_filename
  else
    for gist in s:gist_list(_).gists
      for filename in gist.files
        call add(candidates,
        \        printf('%s:%s/%s/%s',
        \                _.scheme,
        \                _.gist_user,
        \                gist.repo,
        \                filename))
      endfor
    endfor
    let head_part = printf('%s:%s/', _.scheme, _.gist_user)
    let tail_part = _.gist_id
  endif

  return [candidates, head_part, tail_part]
endfunction




function! metarw#gist#read(fakepath)  "{{{2
  let _ = s:parse_incomplete_fakepath(a:fakepath)

  if _.filename_given_p
    return s:read_content(_)
  elseif _.id_given_p
    return s:read_metadata(_)
  else
    return s:read_list(_)
  endif
endfunction




function! metarw#gist#write(fakepath, line1, line2, append_p)  "{{{2
  let _ = s:parse_incomplete_fakepath(a:fakepath)

  if g:metarw_gist_user != _.gist_user || !_.filename_given_p
    return ['error', 'Not supported']
  endif

  let file_ext = fnamemodify(_.gist_filename, ':e')
  let content = join(getline(a:line1, a:line2), "\n")
  " BUGS: Not obvious whether the request was successful.
  call http#post('https://gist.github.com/gists/' . _.gist_id, {
  \   '_method': 'put',
  \   printf('file_ext[%s]', _.gist_filename): file_ext,
  \   printf('file_name[%s]', _.gist_filename): _.gist_filename,
  \   printf('file_contents[%s]', _.gist_filename): content,
  \   'login': g:metarw_gist_user,
  \   'token': g:metarw_gist_token,
  \ }, {'Expect': ''})
  return ['done', '']
endfunction




" Misc.  "{{{1
function! s:parse_incomplete_fakepath(incomplete_fakepath)  "{{{2
  let _ = {}

  let fragments = split(a:incomplete_fakepath, '^\l\+\zs:', !0)
  if len(fragments) <= 1
    echoerr 'Unexpected a:incomplete_fakepath:' string(a:incomplete_fakepath)
    throw 'metarw:gist#e1'
  endif
  let fragments = insert(split(fragments[1], '/'), fragments[0], 0)

  let _.scheme = fragments[0]

  " {gist_user}
  let i = 1
  if i < len(fragments)
    let _.gist_user = fragments[i]
    let i += 1
  else
    let _.gist_user = g:metarw_gist_user
  endif

  " {gist_id}
  if i < len(fragments)
    let _.id_given_p = !0
    let _.gist_id = fragments[i]
    let i += 1
  else
    let _.id_given_p = !!0
    let _.gist_id = ''
  endif

  " {gist_filename}
  if i < len(fragments)
    let _.filename_given_p = !0
    let _.gist_filename = fragments[i]
    let i += 1
  else
    let _.filename_given_p = !!0
    let _.gist_filename = ''
  endif

  return _
endfunction




function! s:gist_metadata(_)  "{{{2
  let api = 'https://gist.github.com/api/v1/json/' . a:_.gist_id
  let result = http#get(api)
  if result.header[0] != 'HTTP/1.1 200 OK'
    echoerr 'Request failed: ' result.header[0]
    return {}
  endif
  return json#decode(result.content)
endfunction




function! s:gist_list(_)  "{{{2
  let api = 'http://gist.github.com/api/v1/json/gists/' . a:_.gist_user
  let result = http#get(api)
  if result.header[0] != 'HTTP/1.1 200 OK'
    echoerr 'Request failed: ' result.header[0]
    return {}
  endif
  return json#decode(result.content)
endfunction




function! s:read_content(_)  "{{{2
  let api = printf('https://raw.github.com/gist/%s/%s',
  \                a:_.gist_id,
  \                a:_.gist_filename)
  let result = http#get(api)
  if result.header[0] != 'HTTP/1.1 200 OK'
    return ['error', 'Request failed: ' result.header[0]]
  endif
  put =result.content
  return ['done', '']
endfunction




function! s:read_metadata(_)  "{{{2
  let result = [{
  \     'label': '../',
  \     'fakepath': printf("%s:%s",
  \                        a:_.scheme,
  \                        a:_.gist_user)
  \  }]
  for filename in s:gist_metadata(a:_).gists[0].files
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
  for gist in s:gist_list(a:_).gists
    for filename in gist.files
      call add(result, {
      \    'label': gist.repo . '/' . filename,
      \    'fakepath': printf('%s:%s/%s/%s',
      \                       a:_.scheme,
      \                       a:_.gist_user,
      \                       gist.repo,
      \                       filename)
      \ })
    endfor
  endfor
  return ['browse', result]
endfunction




" __END__  "{{{1
" vim: foldmethod=marker
