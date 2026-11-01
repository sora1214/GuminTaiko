-- AI曲選択画面.フォルダ内容表示クラスLua
-- Masayuki_Teraoka@al.bandainamco.jp

AIGenreDispData = {}
function AIGenreDispData.New(iParentMc)
	return
	{
		main_mc_ = iParentMc,
		Init = function(this)
		end,
		
		-- 看板内のフォルダデータ設定.
		SetFolderData = function(this, folderData)
		
			Data = folderData
			this:AdaptationData(Data)
		end,

		-- フォルダデータ適応.
		AdaptationData = function(this, genreData)
		
			if (genreData) then
				this:SetFolderText(genreData)
				this:SetFolderColor(genreData)
				this:SetFolderPattern(genreData)
				this:SetFolderCharacter(genreData)
			end
		end,
		
		-- ジャンルフォルダのテキスト指定
		SetFolderText = function(this, genreData)
			
			if (genreData.genre_id == "shop") then
				this.main_mc_:GotoAndStop("main/board/text_kanban_title_genre", shopIdStr)
				this.main_mc_:GotoAndStop("main/board/text_kanban_intro_genre", shopIdStr)
			else
				this.main_mc_:GotoAndStop("main/board/text_kanban_title_genre", genreData.genre_id)
				this.main_mc_:GotoAndStop("main/board/text_kanban_intro_genre", genreData.genre_id)
			end
			
			this.main_mc_:SetText("main/board/text_kanban_title_genre/text_kanban_title_genre","text_kanban_title_genre","folder_"..genreData.genre_id)	
			this.main_mc_:SetText("main/board/text_kanban_intro_genre/text_kanban_intro_genre","text_kanban_intro_genre","folder_intro_"..genreData.genre_id)
		end,
		
		-- ジャンルフォルダの色指定
		SetFolderColor = function(this, genreData)
		
			if (genreData.genre_id == "shop") then
				this.main_mc_:GotoAndStop("main/board/board_top",shopIdStr)
				this.main_mc_:GotoAndStop("main/board/board_center",shopIdStr)
				this.main_mc_:GotoAndStop("main/board/board_bottom",shopIdStr)
			else
				this.main_mc_:GotoAndStop("main/board/board_top",genreData.genre_id)
				this.main_mc_:GotoAndStop("main/board/board_center",genreData.genre_id)
				this.main_mc_:GotoAndStop("main/board/board_bottom",genreData.genre_id)
			end
		end,
		
		-- ジャンルフォルダの模様指定
		SetFolderPattern = function(this, genreData)
			-- ショップフォルダの場合は季節で切り替える必要あり
			if (genreData.genre_id == "shop") then
				this.main_mc_:GotoAndStop("main/board/pattern", shopIdStr)
			else
				this.main_mc_:GotoAndStop("main/board/pattern", genreData.genre_id)
			end
		end,
		
		-- ジャンルフォルダのキャラクター変更
		SetFolderCharacter = function(this, genreData)
			--this.main_mc_:GotoAndStop("main/board/genre_kanban_chara_left", genreData.genre_id)
			--this.main_mc_:GotoAndStop("main/board/genre_kanban_chara_right", genreData.genre_id)
			
			-- ショップフォルダの場合は季節で切り替える必要あり
			-- if (genreData.genre_id == "shop") then
				-- this.main_mc_:GotoAndStop("main/board/genre_kanban_chara_left", shopIdStr)
				-- this.main_mc_:GotoAndStop("main/board/genre_kanban_chara_right", shopIdStr)
			-- else

			
			-- 横から出てくるキャラクターを強制的にオフにする
			this.main_mc_.main.board.genre_kanban_chara_left:SetVisible(false)
			this.main_mc_.main.board.genre_kanban_chara_right:SetVisible(false)
		end
	}
end

