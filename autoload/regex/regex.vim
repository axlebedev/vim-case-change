" NOTE
" How to add regex:
" 1. (In folder 'autoload/regex/case') Copypaste any file
" 2. (In new file) Main work: change values in that file: 
"     - regex
"     - array of names of this case (Warning: it should not repeat any of existing one)
"     - function 'StringToParts': how incoming string should be divided into parts 
"       example for camelCase: 'oneTWOThree' => ['one','TWO','three']
"       every word should be in lowercase, abbriveation - in upper case
"     - function 'PartsToString': how incoming array of words should be squashed into one
"     - empty function 'init' - for correct initialization of export variables
" 3. (In 'autoload/regex/regex') 'call regex#<casename>#init()'
" 4. (In 'autoload/regex/regex') Add new '...#case' to 'casesArrays'
" 5. (In vimrc) Add new case to corresponding casesOrder

import '../getconfig.vim' 

import './case/camel.vim'
import './case/camel_abbr.vim'
import './case/lower.vim'
import './case/lower_dash.vim'
import './case/lower_underscore.vim'
import './case/pascal.vim'
import './case/title.vim'
import './case/undefined.vim' as undefinedCase
import './case/upper.vim'
import './case/upper_space.vim'
import './case/upper_underscore.vim'

call func#init()

let s:groups = {
    \ 'undefined': 'group-undefined',
    \ 'letter': 'group-letter',
    \ 'word': 'group-word',
    \ 'sentence': 'group-sentence',
\ }
let regex#regex#groups = s:groups

" =============================================================================

let s:savedParts = []
let s:savedGroup = s:groups.undefined
let s:savedCase = 0
let s:sessionCount = 0

" This one will be called on end of session, from SessionController
function! regex#regex#OnSessionEnd() abort
    let s:savedParts = []
    let s:savedGroup = s:groups.undefined
    let s:savedCase = 0
    let s:sessionCount = 0
endfunction

" =============================================================================

let s:casesArrays = {
\ 'letter': [
\     s:lower.lower,
\     s:upper.upper
\ ],
\ 'word': [
\     s:lower.lower,
\     s:upper.upper,
\     s:title.title
\ ],
\ 'sentence': [
\     s:camel.camel,
\     s:camel_abbr.camel_abbr,
\     s:lower_dash.lower_dash,
\     s:lower_underscore.lower_underscore,
\     s:pascal.pascal,
\     s:title.title,
\     s:upper_underscore.upper_underscore,
\     s:upper_space.upper_space,
\ ],
\ 'undefined': [s:undefinedCase.undefinedCase],
\ }

" =============================================================================

function! s:FindCaseByName(name, group)
    if (a:group == s:groups.letter)
        let i = 0
        while (i < s:casesArrays.letter->len())
            if (s:casesArrays.letter[i].name->index(a:name) > -1)
                return s:casesArrays.letter[i]
            endif
            let i += 1
        endwhile
    elseif (a:group == s:groups.word)
        let i = 0
        while (i < s:casesArrays.word->len())
            if (s:casesArrays.word[i].name->index(a:name) > -1)
                return s:casesArrays.word[i]
            endif
            let i += 1
        endwhile
    elseif (a:group == s:groups.sentence)
        let i = 0
        while (i < s:casesArrays.sentence->len())
            if (s:casesArrays.sentence[i].name->index(a:name) > -1)
                return s:casesArrays.sentence[i]
            endif
            let i += 1
        endwhile
    endif
    return s:undefinedCase.undefinedCase
endfunction

function! s:GetCasesOrderByGroup(group) abort
    if (a:group == s:groups.letter)
        return s:getconfig.GetConfig('letterCasesOrder')
    elseif (a:group == s:groups.word)
        return s:getconfig.GetConfig('wordCasesOrder')
    endif
    return s:getconfig.GetConfig('sentenceCasesOrder')
endfunction

function! s:GetNextCase(group, oldCase, d) abort
    let casesOrderArray = s:GetCasesOrderByGroup(a:group)

    let curindex = 0
    while (curindex < casesOrderArray->len())
        let oneOfNames = casesOrderArray[curindex]
        if (a:oldCase.name->index(oneOfNames) > -1)
            break
        endif
        let curindex += 1
    endwhile
    let nextCaseIndex = (curindex + a:d) % casesOrderArray->len()

    let nextCaseName = casesOrderArray[nextCaseIndex]
    return s:FindCaseByName(nextCaseName, a:group)
endfunction

" =============================================================================
"
function! s:GetWordGroup(word) abort
    if (a:word->len() < 2)
        return s:groups.letter
    elseif (
      \    a:word =~# '\v\C^[[:upper:][:digit:]]+$' 
      \ || a:word =~# '\v\C^[[:lower:][:digit:]]+$'
      \ || a:word =~# '\v\C^[[:upper:]][[:lower:][:digit:]]+$'
      \ )
        " if only upper or digits or only lower and digits - this is single word
        return s:groups.word
    endif

    return s:groups.sentence 
endfunction

function! s:GetWordCase(word, group) abort
    let cases = [s:undefinedCase.undefinedCase]
    if (a:group == s:groups.letter)
        let cases = s:casesArrays.letter
    elseif (a:group == s:groups.word)
        let cases = s:casesArrays.word
    elseif (a:group == s:groups.sentence)
        let cases = s:casesArrays.sentence
    endif

    let i = 0
    while (i < cases->len())
        if (a:word =~# cases[i].regex)
            return cases[i]
        endif
        let i += 1
    endwhile

    return s:undefinedCase.undefinedCase
endfunction

function! regex#regex#GetNextWord(oldWord, isPrev) abort
    if (s:sessionCount == 0)
        let s:savedGroup = s:GetWordGroup(a:oldWord)
        let s:savedCase = s:GetWordCase(a:oldWord, s:savedGroup)
        let s:savedParts = s:savedCase.StringToParts(a:oldWord)
    endif
    
    let s:sessionCount += a:isPrev ? -1 : 1
    let nextCase = s:GetNextCase(s:savedGroup, s:savedCase, s:sessionCount)
    let newWord = nextCase.PartsToString(s:savedParts->copy())
    return newWord
endfunction
