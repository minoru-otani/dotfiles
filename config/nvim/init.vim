set autoindent         "改行時に自動でインデントする
set autoread           "外部でファイルに変更があった場合に自動的に読み込む
set backspace=indent,eol,start "近代的なバックスペースの振る舞い
set belloff=all        "ビープ音を消す
set clipboard=unnamed  "yank した文字列をクリップボードにコピー
set expandtab          "タブ入力を空白に変換
set hls                "検索した文字をハイライトする
set nocompatible       "viとの互換性なし
set relativenumber number             "行番号を表示
set shiftwidth=2       "自動インデント時に入力する空白の数
set tabstop=2          "タブを何文字の空白に変換するか
set termguicolors      "TrueColor対応"
set wildmode=longest,list "タブで補完されるファイルをshellライクに
set mouse=a            "マウスを使えるようにする
"set cmdheight=2        "コマンドラインの高さを2行にする
set updatetime=300     "gitgutterのアップデートタイムを短くする（デフォルト4000ms）
set shortmess+=c       "https://qiita.com/koara-local/items/40153e1135bb8101cf2d

"===========================================
"Leader キーをデフォルトの"\"からspaceに変更
"Local leaderキーを割り当てる(Latex用)
"===========================================
let mapleader = "\<Space>"
let maplocalleader = ","
let g:tex_flavor = "latex"

"Tab window switch
nmap <C-p> <Plug>AirlineSelectPrevTab
nmap <C-n> <Plug>AirlineSelectNextTab
"Split window switch
nmap <C-h> <Plug>WinMoveLeft
nmap <C-j> <Plug>WinMoveDown
nmap <C-k> <Plug>WinMoveUp
nmap <C-l> <Plug>WinMoveRight
"FZF
nnoremap <silent> <leader>f :Files<CR>
nnoremap <silent> <leader>g :GFiles<CR>
nnoremap <silent> <leader>G :GFiles?<CR>
nnoremap <silent> <leader>b :Buffers<CR>
nnoremap <silent> <leader>h :History<CR>
nnoremap <silent> <leader>r :Rg<CR>
"Git gutter
"一旦GitGutterのkeymapをなしにする
let g:gitgutter_map_keys = 0
"https://wonderwall.hatenablog.com/entry/2016/03/26/211710
"https://qiita.com/youichiro/items/b4748b3e96106d25c5bc
nmap g] <Plug>(GitGutterNextHunk)
nmap g[ <Plug>(GitGutterPrevHunk)
nmap gs <Plug>(GitGutterStageHunk)
nmap gu <Plug>(GitGutterUndoHunk)
nmap gv <Plug>(GitGutterPreviewHunk)
nmap gf :GitGutterFold<CR>
" 記号の色を変更する
highlight GitGutterAdd ctermfg=green
highlight GitGutterChange ctermfg=blue
highlight GitGutterDelete ctermfg=red

"========================================="
" plugin Manager: dein.vim setting
"========================================="
" プラグインが実際にインストールされるディレクトリ
let s:dein_dir = expand('~/.cache/dein')
" dein.vim 本体
let s:dein_repo_dir = s:dein_dir . '/repos/github.com/Shougo/dein.vim'
" dein.vim がなければ github から落としてくる
if &runtimepath !~# '/dein.vim'
  if !isdirectory(s:dein_repo_dir)
    execute '!git clone https://github.com/Shougo/dein.vim' s:dein_repo_dir
  endif
  execute 'set runtimepath^=' . fnamemodify(s:dein_repo_dir, ':p')
endif

" 設定開始
if dein#load_state(s:dein_dir)
  call dein#begin(s:dein_dir)

  " プラグインリストを収めた TOML ファイル
  " 予め TOML ファイル（後述）を用意しておく
  let g:rc_dir    = expand('~/.config/nvim/rc')
  let s:toml      = g:rc_dir . '/dein.toml'
  let s:lazy_toml = g:rc_dir . '/dein_lazy.toml'

   " TOML を読み込み、キャッシュしておく
  call dein#load_toml(s:toml,      {'lazy': 0})
  call dein#load_toml(s:lazy_toml, {'lazy': 1})

  call dein#end()
  call dein#save_state()
endif

" もし、未インストールものものがあったらインストール
if dein#check_install()
  call dein#install()
endif

" tomlファイルから削除されたプラグインは削除
let s:removed_plugins = dein#check_clean()
if len(s:removed_plugins) > 0
  call map(s:removed_plugins, "delete(v:val, 'rf')")
  call dein#recache_runtimepath()
endif

let g:dein#install_max_processes = 16

"========================================="
" setting
"========================================="
filetype plugin indent on

"Credit joshdick
"Use 24-bit (true-color) mode in Vim/Neovim when outside tmux.
"If you're using tmux version 2.2 or later, you can remove the outermost $TMUX check and use tmux's 24-bit color support
"(see < http://sunaku.github.io/tmux-24bit-color.html#usage > for more information.)
if (empty($TMUX))
  if (has("nvim"))
    "For Neovim 0.1.3 and 0.1.4 < https://github.com/neovim/neovim/pull/2198 >
    let $NVIM_TUI_ENABLE_TRUE_COLOR=1
  endif
  "For Neovim > 0.1.5 and Vim > patch 7.4.1799 < https://github.com/vim/vim/commit/61be73bb0f965a895bfb064ea3e55476ac175162 >
  "Based on Vim patch 7.4.1770 (`guicolors` option) < https://github.com/vim/vim/commit/8a633e3427b47286869aa4b96f2bfc1fe65b25cd >
  " < https://github.com/neovim/neovim/wiki/Following-HEAD#20160511 >
  if (has("termguicolors"))
    set termguicolors
  endif
endif

set background=dark " for the dark version
" set background=light " for the light version
colorscheme one
syntax enable
let g:airline_theme = 'one'
" powerline enable(最初に設定しないとダメ)
let g:airline_powerline_fonts = 1
" バッファーをタブのように利用する
let g:airline#extensions#tabline#enabled = 1
" 選択行列の表示をカスタム(デフォルトだと長くて横幅を圧迫するので最小限に)
let g:airline_section_z = airline#section#create(['windowswap', '%3p%% ', 'linenr', ':%3v'])
" 空白を検出しないようにする（defaultでは検出する）
" let g:airline#extensions#whitespace#enabled = 0
" gitのHEADから変更した行の+-を非表示(vim-gitgutterの拡張)
let g:airline#extensions#hunks#enabled = 0

"========================
"Python 3.x系のPathを設定
"========================
let g:python3_host_prog = '/usr/local/bin/python3'

"=========================
"Cocのショートカットを設定
"=========================
"popup windowの透過率を変える
set winblend=30
"補完候補の窓の透過率を変える
set pumblend=30
"<tab>とShift-<tab>で補完候補の切り替え、<CR>で候補を確定
inoremap <silent><expr> <TAB>
      \ coc#pum#visible() ? coc#pum#next(1):
      \ CheckBackSpace() ? "\<Tab>" :
      \ coc#refresh()
inoremap <expr><S-TAB> coc#pum#visible() ? coc#pum#prev(1) : "\<C-h>"

function! CheckBackSpace() abort
  let col = col('.') - 1
  return !col || getline('.')[col - 1]  =~ '\s'
endfunction

"Use <CR> to confirm completion
inoremap <expr> <cr> coc#pum#visible() ? coc#_select_confirm() : "\<CR>"
"To make <CR> to confirm selection of selected complete item or notify coc.nvim
"to format on enter.
inoremap <silent><expr> <CR> coc#pum#visible() ? coc#_select_confirm()
                              \: "\<C-g>u\<CR>\<c-r>=coc#on_enter()\<CR>"

" GoTo code navigation.
nmap <silent> gd <Plug>(coc-definition)
nmap <silent> gy <Plug>(coc-type-definition)
nmap <silent> gi <Plug>(coc-implementation)
nmap <silent> gr <Plug>(coc-references)

" Use <c-space> to triger completion.
" 日本語ー英語のスイッチとバッティングしている。
" inoremap <silent><expr> <c-space> coc#refresh()

" Use K to show documentation in preview window.
nnoremap <silent> K :call ShowDocumentation()<CR>

function! ShowDocumentation()
  if CocAction('hasProvider', 'hover')
    call CocActionAsync('doHover')
  else
    call feedkeys('K', 'in')
  endif
endfunction

"全てのfloat windowを閉じる https://wonwon-eater.com/nvim-susume-lsp-coc/#outline__6
nmap <esc><esc> <cmd>call coc#float#close_all()<cr>

"test
function! SayHello()
  echo 'hello, world'
endfunction
noremap <Plug>(say_hello) :<C-u>call SayHello()<CR>

" coc-definitionで<ctrl-t>でsplit, vsplit, tabeでその定義ファイルを開く
" https://zenn.dev/skanehira/articles/2021-12-12-vim-coc-nvim-jump-split
" [
"   {"text": "(e)dit", "value": "edit"}
"   {"text": "(n)ew", "value": "new"}
" ]
" NOTE: text must contains '()' to detect input and its must be 1 character
function! ChoseAction(actions) abort
  echo join(map(copy(a:actions), { _, v -> v.text }), ", ") .. ": "
  let result = getcharstr()
  let result = filter(a:actions, { _, v -> v.text =~# printf(".*\(%s\).*", result)})
  return len(result) ? result[0].value : ""
endfunction

function! CocJumpAction() abort
  let actions = [
        \ {"text": "(s)plit", "value": "split"},
        \ {"text": "(v)slit", "value": "vsplit"},
        \ {"text": "(t)ab", "value": "tabedit"},
        \ ]
  return ChoseAction(actions)
endfunction

nnoremap <silent> <C-t> :<C-u>call CocActionAsync('jumpDefinition', CocJumpAction())<CR>

