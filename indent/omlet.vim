" Vim indent file
" Language:    OCaml
" Maintainer:  David Baelde <firstname.name@ens-lyon.org>
" Last Change: 2005 Feb 09
" Changelog:   - Second loading did nothing interesting, now corrected.
"              - Indentation of and in let definitions
"              - Syntax highlighting is turned on, cause I rely on synIDs
"              - Indentation of ;; and correction of a bug related to
"                variables names beginning with let -- thanks to micha !
"              - Toplevel let definitions after end of modules/classes
"              - Corrected a bug related with garbage-eating operators
"                (let-in does that, if-then doesn't)
"              - Better mangement of && || and ,
"              - Basic jumping now goes threw ::, @, <- ... and correctly
"                goes back on for/while statements, and strings
"              - Corrected a few indent vs. col problems
"              - Added folding expression

" omlet.vim -- a set of files for working on OCaml code with VIm
" Copyright (C) 2005 David Baelde
"
" This program is free software; you can redistribute it and/or modify
" it under the terms of the GNU General Public License as published by
" the Free Software Foundation; either version 2 of the License, or
" (at your option) any later version.
"
" This program is distributed in the hope that it will be useful,
" but WITHOUT ANY WARRANTY; without even the implied warranty of
" MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
" GNU General Public License for more details.
"
" You should have received a copy of the GNU General Public License
" along with this program; if not, write to the Free Software
" Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

" TODO AtomBackward() does not completely handle comments
" it should use s:search, and maybe skip :: & co in one step
" TODO indentation fun/arg shouldn't be strict ?
" TODO take a look at error matching facilities provided by official ocaml.vim
" TODO cannot re-indent when || is typed at begining of line

" Only load this indent file when no other was loaded.
if exists("b:did_indent")
  finish
endif
let b:did_indent = 1

setlocal expandtab
setlocal comments=s1l:(*,mb:*,ex:*)
setlocal fo=croq
syntax enable
setlocal indentexpr=GetOMLetIndent(v:lnum)
setlocal indentkeys=0{,0},!^F,o,O,0=let\ ,0=and,0=in,0=end,0),0=do,0=done,0=then,0=else,0=with,0\|,0=->,0=;;,0=module,0=struct,0=sig,0=class,0=object,0=val,0=method,0=initializer,0=inherit,0=open,0=include,0=exception,0=external,0=type,0=&&

" Do not define our functions twice
if exists("*GetOMLetIndent")
  finish
endif
let b:did_indent = 1

" {{{ A few utils

function s:save()
  return line2byte(line('.'))+col('.')-1
endfunction

function s:restore(v)
  execute 'goto ' a:v
endfunction

function s:searchpair(beg,mid,end,flags)
  return searchpair(a:beg,a:mid,a:end,a:flags,'synIDattr(synID(line("."), col("."), 0), "name") =~? "string\\|comment"')
endfunction

function s:search(re)
  while search('\*)\_s*\%#','bW')
    call searchpair('(\*','','\*)','bW')
  endwhile
  return search(a:re,'bW')
endfunction

let s:begend = '\%(\<begin\>\|\<object\>\|\<struct\>\|\<sig\>\)'

function OMLetBegendBackward()
  return s:searchpair(s:begend,'','\<end\>','bW')
endfunction

" }}}

" {{{ Basic jumping.
" Goes to the beginning of the previous (exclusive) block.
" It is stopped by any non-trivial syntax.

let s:blockstop = '\(\%^\|(\|{\|\[\|\<begin\>\|;\|,\|&&\|||\|\<try\>\|\<match\>\|\<with\>\||\|->\|\<when\>\|\<of\>\|\<function\>\|=\|\<let\>\|\<in\>\|\<for\>\|\<to\>\|\<do\>\|\<while\>\|\<if\>\|\<then\>\|\<else\>\|\<sig\>\|\<struct\>\|\<object\>\)\_s*\%#'

function OMLetAtomBackward()
  let s = s:save()

  if search('\*)\_s*\%#','bW')
    call searchpair('(\*','','\*)','bW')
    return OMLetAtomBackward()

  elseif search(')\_s*\%#','bW')
    return s:searchpair('(','',')','bW')

  elseif search('\]\_s*\%#','bW')
    return s:searchpair('\[','','\]','bW')

  elseif search('}\_s*\%#','bW')
    return s:searchpair('{','','}','bW')

  elseif search('"\_s*\%#','bW')
    while search('\_."','bW')
      if synIDattr(synID(line("."), col("."), 0), "name") != "ocamlString"
        call search('"')
        return 1
      endif
    endwhile
    throw "didn't find beginning of string"

  elseif search('\<done\>\_s*\%#','bW')
    call s:searchpair('\<do\>','','\<done\>','bW')
    return s:searchpair('\%(\<while\>\|\<for\>\)','','\<do\>','bW')

  elseif search('\<end\>\_s*\%#','bW')
    if synIDattr(synID(line("."), col("."), 0), "name") == "ocamlKeyword"
      call s:searchpair('\<begin\>','','\<end\>','bW')
      return 1
    else
      call s:restore(s)
    endif

  elseif search('\%(::\|\.\|<-\|:=\|@\)\_s*\%#','bW')
    return OMLetAtomBackward()

  elseif search('=\_s*\%#','bW')
    if search('\%(\<let\>\|\<val\>\|\<method\>\|\<type\>\)[^=]\+\%#','bW')
      call s:restore(s)
    else
      return 1
    endif
  endif

  if search(s:blockstop,'bW')
    " Stop moving in front of those block delimiters
    call s:restore(s)
    return 0

  else
    " Otherwise, move backward, skipping an atom
    return search('\<','bW')
  endif
endfunction

function OMLetAtomsBackward()
  while OMLetAtomBackward()
  endwhile
endfunction

" }}}

" {{{ We still have problems with let, match, and else, which have no
" closing keyword.

function OMLetMatchHeadBackward()
  if search('\<with\>\_s*\%#','bW')
    call s:searchpair('\%(\<try\>\|\<match\>\)','','\<with\>','bW')
  elseif search('\<fun\>\_s*\%#','bW')
  elseif search('\<function\>\_s*\%#','bW')
  elseif search('\<type\>\_[^=]\+=\_s*\%#','bW')
  else
    throw "Indentation failed!"
  endif
endfunction

function OMLetIfHeadBackward()
  if search('\<then\_s*\%#','bW')
    call s:searchpair('\<if\>','','\<then\>','bW')
  else
    throw "Indentation failed!"
  endif
endfunction

function OMLetExprBackward(lf,gbg)
  if (a:lf != 'then' || a:gbg) && search('\<then\_s*\%#','bW')
    call s:searchpair('\<if\>','','\<then\>','bW')
    call OMLetExprBackward(a:lf,a:gbg)
    return 1

  elseif search('\<else\_s*\%#','bW')
    call OMLetBlockBackward('then',0)
    call OMLetIfHeadBackward()
    call OMLetExprBackward(a:lf,a:gbg)
    return 1
 
  " These operators have priority on ';' so we must skip them.
  " However, it is a bad programming style to use them at toplevel
  " in a sequence: ignore should be around.
  elseif search('\%(||\|&&\)\_s*\%#','bW')
    call OMLetExprBackward(a:lf,a:gbg)
    return 1

  elseif OMLetAtomBackward()
    call OMLetAtomsBackward()
    call OMLetExprBackward(a:lf,a:gbg)
    return 1

  else
    return 0
  endif
endfunction

" Now we include let and match...
" BlockBackward return 1 iff it succeeds in moving backward
" that's not a very strong specification :/
function OMLetBlockBackward(lf,gbg)
  if OMLetExprBackward(a:lf,a:gbg) " Doesn't move the point on failure
    call OMLetBlockBackward(a:lf,a:gbg)
    return 1

  elseif search('\<in\>\_s*\%#','bW')
    call s:searchpair('\<let\>','','\<in\>','bW')
    call OMLetBlockBackward(a:lf, 0) " [let ... in] eats the garbage
    return 1

  elseif search('[;,]\_s*\%#','bW')
    call OMLetBlockBackward(a:lf,1) " sequence is the garbage
    return 1

  elseif search('\<when\_s*\%#','bW')
    call OMLetBlockBackward(a:lf,0)
    return 1

  elseif search('\%(->\|\<of\>\)\_s*\%#','bW')
    call OMLetPatternBackward()
    call OMLetBlockBackward('match',0)
    if a:lf != 'match'
      call OMLetMatchHeadBackward()
      call OMLetBlockBackward(a:lf,0) " match has eaten the garbage
    endif
    return 1

  endif
  return 0
endfunction

function OMLetPatternBackward()
  call OMLetBlockBackward('',0)
  call search('|\_s*\%#','bW') " allow failure
endfunction

" }}}

" {{{ Indentation function
" The goal is to return a 'correct' indentation,
" assuming that the previous lines are well indented.

let s:mode_relative = 0

function OMLetSetRelative(b)
  let s:mode_relative = a:b
endfunction

function s:indent(l)
  if s:mode_relative
    " Two possible indentation modes:
    " 1. (stricter) relative
    return col(a:l)-1
  else
    " 2. (more usual) incremental
    return indent(a:l)
  endif
endfunction

function GetOMLetIndent(l)

  " Go to the first non-blank char on the line to be indented.

  exe a:l

  " Indentation inside comments
  if synIDattr(synID(line("."), col("."), 0), "name") =~? 'comment'
    let s = s:save()
    call searchpair('(\*','','\*)','bW')
    if s != s:save()
      " We were strictly inside the comment, and we are now at its beginning
      call search('\*[^\*]')
      return col('.')-1
    endif
    " No need to restore, there was no move
  endif

  " {{{ Keyword alignments
  " How to indent a line starting with a keyword

  if getline(a:l) =~ '^\s*(\*' && getline(a:l-1) =~ '^\s*$'
    call searchpair('(\*','','\*)')
    let new = nextnonblank(line('.')+1)
    if new == a:l
      return 0
    else
      return GetOMLetIndent(new)
    endif
  endif

  if getline(a:l) =~ '^\s*\<end\>'
    call s:searchpair(s:begend,'','\<end\>','bW')
    return s:indent(".")
  endif

  if getline(a:l) =~ '^\s*}'
    call s:searchpair('{','','}','bW')
    return s:indent(".")
  endif

  if getline(a:l) =~ '^\s*)'
    call s:searchpair('(','',')','bW')
    return s:indent(".")+1
  endif

  if getline(a:l) =~ '^\s*\<done\>'
    call s:searchpair('\<do\>','','\<done\>','bW')
    call s:searchpair('\%(\<while\>\|\<for\>\)','','\<do\>','bW')
    return s:indent(".")
  endif

  if getline(a:l) =~ '^\s*\<do\>'
    call s:searchpair('\<\(while\|for\)\>','','\<do\>','bW')
    return s:indent(".")
  endif

  " I want 'with' to be stricly aligned on 'match'
  " since I align patterns on 'match'
  if getline(a:l) =~ '^\s*with\>'
    call s:searchpair('\%(\<try\>\|\<match\>\)','','\<with\>','bW')
    return col(".")-1
  endif

  if getline(a:l) =~ '^\s*\<then\>'
    call s:searchpair('\<if\>','','\<then\>','bW')
    return col(".")-1
  endif

  if getline(a:l) =~ '^\s*else\>'
    call OMLetBlockBackward('then',0)
    if s:search('\<then\_s*\%#')
      call s:searchpair('\<if\>','','\<then\>','bW')
    endif
    return col(".")-1
  endif

  if getline(a:l) =~ '^\s*->'
    call OMLetPatternBackward()
    return col(".")+1
  endif

  " ;; alone is indented as toplevel defs
  if getline(a:l) =~ '^\s*;;'
    if OMLetBegendBackward()
      return col('.')+1
    else
      return 0
    endif
  endif

  " The problem with { is that it gets standard indentation
  " except in type definitions, where the standard is +4, and I need to
  " put it back to the "normal" indentation, which isn't obvious
  if getline(a:l) =~ '^\s*{'
    return s:indent(a:l-1)+2 " TODO that's weak !
  endif

  " Easy toplevel definitions
  if getline(a:l) =~ '^\s*\%(\<open\>\|\<include\>\|\<struct\>\|\<object\>\|\<sig\>\|\<val\>\|\<module\>\|\<class\>\|\<type\>\|\<method\>\|\<initializer\>\|\<inherit\>\|\<exception\>\|\<external\>\)'
    if s:searchpair(s:begend,'','\<end\>','bW')
      return s:indent('.')+2
    else
      return 0
    endif
  endif

  " The next three tests are for indenting toplevel let

  " let after a high-level (not matching a begin)
  if getline(a:l) =~ '^\s*let\>' && s:search('\<end\>\_s*\%#') && synIDattr(synID(line('.'),col('.'),0),'name') != 'ocamlKeyword'
    call OMLetBegendBackward()
    return col('.')-1
  else
    exe a:l
  endif

  " let at the beginning of a structure
  if getline(a:l) =~ '^\s*let\>' && s:search('\<struct\>\_s*\%#')
    return col('.')+1
  endif

  " let after another value-level construct
  if getline(a:l) =~ '^\s*let\>' && (OMLetAtomBackward() || search(';;\_s*\%#'))
    if OMLetBegendBackward()
      return col('.')+1
    else
      return 0
    endif
  else
    exe a:l
    " That was undoing the AtomBackward
  endif

  " let/and
  if getline(a:l) =~ '^\s*and\>' && OMLetBlockBackward('',0)
    if s:search('\%(\<let\>\|\<and\>\)\_[^=]\+=\_s*\%#')
      return s:indent(".")
    else
      exe a:l
    endif
  endif

  " Now we deal with let/in
  if getline(a:l) =~ '^\s*in\>'
    call s:searchpair('\<let\>','','\<in\>','bW')
    return s:indent(".")
  endif

  " let after let isn't indented
  if getline(a:l) =~ '^\s*\<let\>' && s:search('\<in\>\_s*\%#')
    call s:searchpair('\<let\>','','\<in\>','bW')
    return s:indent(".")
  endif

  " && and ||
  if getline(a:l) =~ '^\s*\%(||\|&&\)'
    call OMLetExprBackward('',0)
    return col(".")-1
  endif

  " Matching clause marker |
  if getline(a:l) =~ '^\s*|'
    call OMLetBlockBackward('match',0)
    call OMLetMatchHeadBackward()
    return col(".")+1
  endif

  " }}}

  " {{{ Beginning of blocks
  " Howto indent a line after some keyword

  " Basic indentation increment
  if s:search('\(\<if\>\|\<begin\>\|\<match\>\|\<try\>\|\<struct\>\|\<sig\>\|\<class\>\|\<let\>\|(\|{\|\<initializer\>\)\_s*\%#')
    return s:indent(".")+2
  endif
  if s:search('\%(\<let\>\|\<module\>\|\<val\>\|\<method\>\)\_[^=]\+=\_s*\%#')
    return s:indent(".")+2
  endif

  " Special increment: 4 for patterns
  if s:search('\<function\>\_s*\%#')
    return col(".")+3
  endif
  if s:search('\<with\>\_s*\%#')
    call s:searchpair('\%(\<match\>\|\<try\>\)','','\<with\>','bW')
    return col(".")+3
  endif
  if s:search('\<type\>\_[^=]\+=\_s*\%#')
    return col(".")+3
  endif

  " Sometimes you increment according to a master keyword

  " IF
  if s:search('\<then\>\_s*\%#')
    call s:searchpair('\<if\>','','\<then\>','bW')
    return col(".")+1
  endif
  if s:search('\<else\_s*\%#')
    call OMLetBlockBackward('then',0)
    call OMLetIfHeadBackward()
    return col(".")+1
  endif

  " MATCH
  if s:search('\<when\_s*\%#')
    call OMLetPatternBackward()
    return s:indent(".")+4
  endif
  if s:search('->\_s*\%#')
    call OMLetPatternBackward()
    call OMLetBlockBackward('match',0)
    call OMLetMatchHeadBackward()
    if search('\%#fun\>')
      return s:indent(".")+2
    else
      return col(".")+5
    endif
  endif

  " WHILE/DO
  if s:search('\<do\>\_s*\%#')
    call s:searchpair('\%(\<while\>\|\<for\>\)','','\<do\>','bW')
    return s:indent(".")+2
  endif

  " LET
  if s:search('\<in\>\_s*\%#')
    call s:searchpair('\<let\>','','\<in\>','bW')
    return s:indent(".")+2
  endif

  " }}}

  " Sequence: find previous instruction's base indentation

  if s:search(';;\_s*\%#')
    if OMLetBegendBackward()
      return col('.')+1
    else
      return 0
    endif
  endif

  if s:search('\%(;\|,\|||\|&&\)\_s*\%#')
    call OMLetExprBackward('',0)
    return col(".")-1
  endif

  " Application: indentation between a function and its arguments

  if OMLetAtomBackward()
    call OMLetAtomsBackward()
    return col(".")+1
  else
    return 0
  endif

endfunction

" }}}
