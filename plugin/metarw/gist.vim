" gist - {abstract}
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

if exists('g:loaded_gist')
  finish
endif




if !exists('g:metarw_gist_user')
  let g:metarw_gist_user = system('git config --global github.user')[:-2]
  if g:metarw_gist_user == ''
    let g:metarw_gist_user = $GITHUB_USER
  end
endif

if !exists('g:metarw_gist_token')
  let g:metarw_gist_token = system('git config --global github.token')[:-2]
  if g:metarw_gist_token == ''
    let g:metarw_gist_token = $GITHUB_TOKEN
  end
endif




command! -bang -range=% -nargs=0 Gist  <line1>,<line2>call s:gist_post()
function! s:gist_post() range
  let api = 'http://gist.github.com/api/v1/json/new'
  let filename = expand('%') != '' ? expand('%') : input('Filename: ')
  let content = join(getline(a:firstline, a:lastline), "\n")
  let result = http#post(api, {
  \   printf('files[%s]', expand('%')): content,
  \   'login': g:metarw_gist_user,
  \   'token': g:metarw_gist_token,
  \   'description': input('Description: ', filename)
  \ }, {'Expect': ''})
  redraw
  if result.header[0] != 'HTTP/1.1 200 OK'
    echoerr 'Request failed: ' result.header[0]
    return
  endif
  let gist = json#decode(result.content).gists[0]
  echo 'https://gist.github.com/' . gist.repo
endfunction




let g:loaded_gist = 1

" __END__
" vim: foldmethod=marker
