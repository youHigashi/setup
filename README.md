# Setup scripts for macOS

**Apple Silicon** のmacOSで、同OSの別端末への(移行アシスタントやバックアップからの復元を伴わない)移行と、クリーンインストールを行う場合を想定した最小限のセットアップを行うためのスクリプトです  
> [!NOTE]
> `macOS 26 Tahoe`で動作の確認をしています    

## 事前準備
1. このリポジトリの`Use this template`から、**自身の公開リポジトリ**として新しく用意してください  
2. 以下のコマンドで現在の`Brewfile`を作成し、リポジトリ内の`Brewfile`を必要に応じて更新してください  
``` shell
brew bundle dump --global
```
> [!NOTE]  
> このリポジトリの`Brewfile`にある`git`, `gh`, `jq`はセットアップに必須のパッケージです  

## 利用方法
以下の3つのスクリプトで構成されているので、必要なものを調整して実行してください  
少なくとも(1)は全ての環境で共通になるものです
1. `bootstrap.sh`: 
   - Command Line Toolsのインストール  
   - Homebrewのインストール  
   - `Brewfile`のパッケージをインストール  

2. `setup.sh`: 
   - SSH鍵を生成してGitHubへ公開鍵を登録  
   - macOSのplist関連を更新  

---  

詳細な移行手順は`MIGRATION.md`参照のこと。
