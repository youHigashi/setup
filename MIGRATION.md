# 移行手順
Apple Silicon Mac から Apple Silicon Mac への開発環境の移行手順。
(Tahoe 26.6で確認済)

## 構成

| 管理対象 | 仕組み | 場所 |
|---|---|---|
| GUI アプリ・一部 CLI | Homebrew（Brewfile） | `github.com/youHigashi/setup` |
| 初期セットアップ | `bootstrap.sh` / `setup.sh` / `Makefile` | 同上 |
| dotfiles・CLI ツール | home-manager（Nix） | `github.com/youHigashi/home-manager-config` → `~/.config/home-manager` |
| secret | sops + age | 鍵：`~/.config/sops/age/keys.txt`（**git 管理外**） |
| プロジェクトごとのツール（Node、pnpm など） | 各プロジェクトの `flake.nix` + direnv | 各リポジトリ |

**原則**
- dotfiles は home-manager だけで管理する。chezmoi などを併用しない。
- `nix profile install` は使わない。CLI は必ず `home.nix` の `home.packages` に書く。
- CLI は Nix、GUI アプリは Brew で管理する。

---

## Phase 1：旧PC（移行の準備）

### 1-1. 命令的にインストールしたものが残っていないか確認する

```sh
nix profile list
```

- `home-manager-path` **だけ**が表示されれば OK。
- それ以外が出たら、`home.nix` の `home.packages` に追記してから削除する。
  ```sh
  nix profile remove <名前>
  home-manager switch --flake ~/.config/home-manager#you_higashi
  ```

### 1-2. HM 管理外の dotfiles が増えていないか確認する

```sh
ls -la ~/.zshrc ~/.zprofile ~/.config/git/config
```

- すべて `/nix/store/...` へのシンボリックリンクであれば OK。
- 実ファイルがあれば、その中身を `home.nix` に取り込む（手順は下記）。
	- **再発防止**：新しいツールは、公式インストーラではなく最初から `home.packages` か `programs.*` で入れる
- `~/.gitconfig` が存在したら、中身を HM に移してから削除する。HM の設定より優先されてしまうため。

> 実ファイルになる典型的な原因：ツールのインストーラ（`curl ... | sh` など）が `.zshrc` に追記し、HM のリンクを実ファイルで置き換えたため。

#### 実ファイルを `home.nix` に取り込む手順

**① 中身を確認し、種類ごとに書く場所を振り分ける**

| 中身 | `home.nix` での書き先 |
|---|---|
| alias | `programs.zsh.shellAliases` |
| 環境変数（`export`） | `home.sessionVariables` |
| その他のシェルコード（`eval ...` など） | `programs.zsh.initContent` |
| git の設定 | `programs.git.settings` |
| 専用モジュールがあるツール（mise、fzf など） | `programs.<名前>.enable = true;`（hook も自動で設定される） |
| 専用モジュールがないツールの設定ファイル | ファイルをリポジトリにコピーし、`xdg.configFile."<パス>".source = ./<ファイル>;` |

専用モジュールの有無は https://home-manager-options.extranix.com で `programs.<名前>` を検索して確認する。

```nix
programs.zsh = {
  shellAliases = { ll = "ls -la"; };
  initContent = ''
    eval "$(something init zsh)"
  '';
};
home.sessionVariables = { EDITOR = "vim"; };
programs.git.settings = { init.defaultBranch = "main"; };
```

**② 適用・確認・後片付け**

```sh
home-manager switch --flake ~/.config/home-manager#you_higashi -b backup  # 実ファイルは *.backup に退避
# 新しいターミナルで動作確認後
rm ~/.zshrc.backup
git -C ~/.config/home-manager commit -am "Absorb unmanaged dotfiles" && git -C ~/.config/home-manager push
```


### 1-3. Brewfile を更新する

```sh
brew bundle dump --global --force
diff ~/.Brewfile ~/setup/Brewfile
```

- 差分を確認して `~/setup/Brewfile` に反映する。
- **HM で管理している CLI（direnv など）は Brewfile から除外する。**

### 1-4. 2つのリポジトリをすべて push する

```sh
for d in ~/.config/home-manager ~/setup; do
  echo "== $d"; git -C "$d" status -s; git -C "$d" log --oneline @{u}..HEAD
done
```

何も表示されない状態にすること。

### 1-5. age 秘密鍵を退避する ⚠️ 最重要

- `~/.config/sops/age/keys.txt` を **USB とパスワードマネージャの両方**に保存する。
- **git には絶対に入れない。**
- 失うと、sops で暗号化したファイルは二度と復号できない。

### 1-6.（任意）git に入れないものを退避する

- `~/.zsh_history`（パスワードなどが混入しうるため git 管理外）
- サーバー用など、GitHub 以外の SSH 秘密鍵

---

## Phase 2：新PC（構築）

> 新PCのユーザー名は `you_higashi` にする。`flake.nix` で固定しているため。

### 2-1. bootstrap を実行する

```sh
bash <(curl -fsSL https://raw.githubusercontent.com/youHigashi/setup/main/bootstrap.sh) \
  --owner youHigashi --branch main
```

Command Line Tools、Homebrew、Brewfile のパッケージのインストールと、`~/setup` へのクローンを行う。

### 2-2. gh 認証と SSH 鍵の登録

```sh
cd ~/setup && make setup
```

- ブラウザで GitHub にログインする。
- SSH 鍵の生成と GitHub への登録、`~/setup` の origin の SSH への切り替え、Finder の設定を行う。

確認：
```sh
git -C ~/setup remote -v   # git@github.com:youHigashi/setup.git であること（.git.git になっていないこと）
ssh -T git@github.com      # "successfully authenticated"
```

### 2-3. Nix をインストールする

```sh
make nix
```

👉 **完了したら、ターミナルを閉じて開き直す。** 開き直さないと PATH に nix が入らない。

### 2-4. age 秘密鍵を配置する

```sh
mkdir -p ~/.config/sops/age && chmod 700 ~/.config/sops/age
# USB などから keys.txt をコピー
chmod 600 ~/.config/sops/age/keys.txt
```

⚠️ **`age-keygen` で新しく生成しないこと。** 新しい鍵では既存の secret を復号できない。

### 2-5. home-manager を適用する

```sh
cd ~/setup && make home
```

- age 鍵の存在を確認し、HM リポジトリをクローンしてから `switch` する。
- 既存の `.zshrc` などは `*.backup` に退避される。

👉 **完了したら、ターミナルを閉じて開き直す。**

### 2-6. 動作確認

```sh
ls -la ~/.zshrc                     # /nix/store へのリンク
nix profile list                    # home-manager-path のみ
which direnv tree node              # すべて ~/.nix-profile/bin/...
git config user.email
echo $SOPS_AGE_KEY_FILE
brew --version
```

- sops で暗号化したファイルがあれば、`sops -d <file>` で復号できるか確認する。
- flake を使うプロジェクトに `cd` し、direnv で環境が読み込まれるか確認する。

### 2-7. Node のファイル監視を確認する

nixpkgs の Node と macOS の組み合わせで、ファイル監視（libuv/kqueue）が壊れた前例がある。

```sh
# ターミナル A
mkdir -p /tmp/watchtest && cd /tmp/watchtest
node -e "require('fs').watch('.',(e,f)=>console.log(e,f));console.log('watching...')"
# ターミナル B
touch /tmp/watchtest/a.txt          # A に "rename a.txt" 等が出れば OK
```

最終的には、実プロジェクトで `pnpm dev` を起動し、ホットリロードが効くことまで確認する。

**NG の場合**
1. `home.nix` の Node のメジャーバージョンを変えて試す。
2. それでも駄目なら、mise を HM で入れ、Node だけを mise で管理する。

### 2-8. 各 CLI に再ログインする

認証情報は移行しない。必要なものだけログインし直す。

- `clasp login`
- `sanity login`
- `docker login`
- Claude Code、Codex、Copilot などの CLI

### 2-9. 片付け

```sh
ls ~/*.backup ~/.*.backup 2>/dev/null   # 中身を確認してから削除
```

---

## 移行しないもの

| 種類 | 例 | 理由 |
|---|---|---|
| Nix の実体 | `.nix-profile`、`.nix-defexpr` | `/nix/store` へのリンクにすぎず、新PCで再生成される |
| 認証情報 | `.clasprc.json`、`.claude.json`、`.docker/`、`.config/gh/hosts.yml`、`.config/sanity`、`.config/configstore` | 漏洩リスクがあるため、再ログインで作り直す |
| キャッシュ・ランタイム | `.cache`、`.npm`、`.bun`、`.nodebrew`、`.colima`、`.zcompdump` | 再生成・再インストールできる |

---

## トラブルシューティング

### プロンプトのたびに `_direnv_hook: no such file or directory: .../direnv`
- **原因**：direnv を削除した後も、現在のシェルに古い hook が残っている。
- **対策**：`home-manager switch` を実行してから、ターミナルを開き直す。

### `home-manager switch` で「既に別のパッケージが同じファイルを提供している」エラー
- **原因**：`nix profile install` で入れたパッケージと、HM で入れるパッケージが重複している。
- **対策**：`nix profile list` で確認し、`home-manager-path` 以外を `nix profile remove` で削除する。

### git の設定変更が反映されない
- **原因**：`~/.gitconfig` が残っていて、HM が生成する `~/.config/git/config` より優先されている。
- **対策**：`~/.gitconfig` を削除する。

### `home.packages` に書いたパッケージで評価エラーになる
- **原因**：コマンド名とパッケージ名は一致するとは限らない（例：`du` は単独のパッケージとしては存在しない）。
- **対策**：`nix search nixpkgs <名前>` や `nix eval nixpkgs#<名前>.name` で、パッケージが存在するか事前に確認する。macOS 標準のコマンドで足りるなら追加しない。
