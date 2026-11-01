-- AI曲選択画面.パネル表示管理クラスLua
-- Masayuki_Teraoka@al.bandainamco.jp

AISongSelectMultiBoard = {}

-- 使うクラスを読み込む
require("common.Sound")
require("ai_song_select.ai_song_select_genre_disp_data")
require("ai_song_select.ai_song_select_song_disp_data")

function AISongSelectMultiBoard.New(mc_kanban_)
	return
	{
		mc_kanban = mc_kanban_,
		
		mc_genreBoard  = {},
		mc_songBoard   = {},
		
		mc_GenreDetail = {},
		mc_SongDetail  = {},

		-- インデックスの値に合わせてジャンル板単体ボードをインスタンスにアタッチする
		LoadMovieGenreBoard = function(this, idx)
			Lumen.LoadMovie("lumen/000_default/enso_ai/song_select/ai_song_select_main_genre_board", "kanban_genre_"..idx)
		end,
		
		-- インデックスの値に合わせて曲板単体ボードをインスタンスにアタッチする
		LoadMovieSongBoard = function(this, idx)
			Lumen.LoadMovie("lumen/000_default/enso_ai/song_select/ai_song_select_main_song_board", "kanban_song_"..idx)
		end,
		
		-- インデックスの値に合わせてフォルダインスタンスを取得する
		SetupGenreBoard = function(this, idx)
			if (Lumen.IsLoadMovieFinish() == true) then
				this.mc_genreBoard[idx] = Lumen.GetMovieClip("kanban_genre_"..idx, true)
			end
		end,
		
		-- インデックスの値に合わせて曲板インスタンスを取得する
		SetupSongBoard = function(this, idx)
			if (Lumen.IsLoadMovieFinish() == true) then
				this.mc_songBoard[idx] = Lumen.GetMovieClip("kanban_song_"..idx, true)
			end
		end,

		-- フォルダのムービークリップを取得して表示用のクラスを作成
		SetupGenreDetail = function(this,idx)
			this.mc_GenreDetail[idx] = {}
			this.mc_GenreDetail[idx] = AIGenreDispData.New(this.mc_kanban:GetChildMc("kanban_genre_"..idx,true))
		end,
		
		-- 曲板のムービークリップを取得して表示用のクラスを作成
		SetupSongDetail = function(this,idx)
			this.mc_SongDetail[idx] = {}
			this.mc_SongDetail[idx] = AISongDispData.New(this.mc_kanban:GetChildMc("kanban_song_"..idx,true))
		end,
		
		-- フォルダ情報をセットする
		SetFolderData = function(this, idx, FolderData)
			this.mc_GenreDetail[idx]:SetFolderData(FolderData)
		end,
		
		-- 曲情報をセットする
		SetSongData = function(this, idx, SongData, SongAttributeData)
			this.mc_SongDetail[idx]:SetSongData(SongData, SongAttributeData)
		end,
		
		-- アイコン情報をセットする
		SetSongIcon = function(this, idx, SongData)
			this.mc_SongDetail[idx]:SetSongIcon(SongData)
		end,
		
		-- アイコン情報を更新する
		UpdateSongIcon = function(this, idx, SongData)
			this.mc_SongDetail[idx]:NextSongIcon(SongData)
		end,
		
		-- 鍵アイコン情報&必要ドンメダルの情報を更新する
		UpdateTokenInformation = function(this, idx, SongData)
			this.mc_SongDetail[idx]:UpdataTokenInfomation(SongData)
		end,

		-- フォーカス時に楽曲名とサブ表記を元に戻す
		SetOpenTypeDispData = function(this, idx, SongData)
			this.mc_SongDetail[idx]:SetOpenTypeDispData(SongData)			
		end,
		
		-- フォルダの表示と曲板の表示を管理する
		SetVisiblePanel = function(this, panel_idx, AIPanelData)
			
			if (AIPanelData.genre_uniqueId < SongGenre.kPops) then
				--Debug.PrintString("SetVisiblePanel_1")
				this.mc_genreBoard[panel_idx]:SetVisible(false)
				this.mc_songBoard[panel_idx]:SetVisible(true)
				
			elseif(AIPanelData.genre_uniqueId >= SongGenre.kPops) then		
				--Debug.PrintString("SetVisiblePanel_2")
				
				this.mc_genreBoard[panel_idx]:SetVisible(true)
				this.mc_songBoard[panel_idx]:SetVisible(false)
			end
		end,
	}
end

