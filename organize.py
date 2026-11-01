from pathlib import Path
import shutil

def organize_songs():
    # フォルダのパス設定
    songs_dir = Path("songs")
    tja_dir = Path("TJA")
    ogg_dir = Path("ogg")

    # 出力先フォルダが存在しない場合は作成
    tja_dir.mkdir(exist_ok=True)
    ogg_dir.mkdir(exist_ok=True)

    # songsフォルダの存在確認
    if not songs_dir.exists():
        print(f"エラー: '{songs_dir}' フォルダが見つかりません。")
        return

    count_tja = 0
    count_audio = 0

    # songsフォルダ以下を再帰的に走査
    for file_path in songs_dir.rglob("*"):
        if file_path.is_file():
            ext = file_path.suffix.lower()

            # TJAファイルの処理
            if ext == ".tja":
                dest = tja_dir / file_path.name
                # 同名ファイルが存在する場合の重複回避
                if dest.exists():
                    dest = tja_dir / f"{file_path.stem}_{file_path.parent.name}{ext}"
                
                shutil.copy2(file_path, dest) # 移動したい場合は shutil.move に変更
                print(f"TJAをコピー: {file_path.name}")
                count_tja += 1

            # 音声ファイル（ogg, mp3）の処理
            elif ext in [".ogg", ".mp3"]:
                dest = ogg_dir / file_path.name
                if dest.exists():
                    dest = ogg_dir / f"{file_path.stem}_{file_path.parent.name}{ext}"
                
                shutil.copy2(file_path, dest) # 移動したい場合は shutil.move に変更
                print(f"音声ファイルをコピー: {file_path.name}")
                count_audio += 1

    print("\n--- 処理完了 ---")
    print(f"TJAファイル: {count_tja} 件")
    print(f"音声ファイル: {count_audio} 件")

if __name__ == "__main__":
    organize_songs()