-- 曲選択画面.楽曲内容表示クラスLua
-- Masayuki_Teraoka@al.bandainamco.jp

SongDispData = {}

function SongDispData.New(iParentMc)
	return
	{	
		beforeDispIcon = "",
		nextDispIcon = "",
		
		tbl_DaniLavel 	  = {"5kyuu", "4kyuu","3kyuu","2kyuu","1kyuu","1dan","2dan","3dan","4dan","5dan",
							"6dan","7dan","8dan","9dan","10dan","11dan","12dan","13dan","14dan"},
		
		tbl_DaniCourseLevel = {"easy", "normal", "hard", "oni", "ura"},
		
		main_mc_ = iParentMc,
		Init = function(this)
		end,
		
		-- 看板内の曲データ設定.
		SetSongData = function(this, songData, songAttributeData)
		
			Data = songData
			
			AttributeData = songAttributeData
			
			this:AdaptationSongData(Data, AttributeData)
		end,
		
		-- 楽曲データ適応.
		AdaptationSongData = function(this, songData, songAttributeData)
		
			if (songData) then

				this:SetSongText(songData)
				this:SetSongColor(songData)
				this:SetSongNetworkErrorColor(songData)
				this:SetSongOpenLevel(songData)
				this:SetSongStar(songData)
				this:SetCrown(songData)
				this:SetScoreRank(songData)
				this:SetPapaMamaIcon(songData)
				this:SetCourseBranchIcon(songData)
				this:SetShopKeyIcon(songData)
				this:SetShopInfo(songData)
				this:SetTextCourseName()
				this:NextSongIcon(songData)
			end
	
		end,
		
		UpdataTokenInfomation = function(this, songData)
		
			if (songData) then
				this:SetShopKeyIcon(songData)
				this:SetShopInfo(songData)
				this:SetSongNetworkErrorColor(songData)
			end
		end,
		
		-- 楽曲板内のテキスト指定
		SetSongText = function(this, songData)
			
			this.main_mc_.main.board.text_kanban_title_song:SetVisible(true)
			this.main_mc_.main.board.text_song_title_sub:SetVisible(true)
			this.main_mc_.main.board.text_song_title_ruby:SetVisible(true)
			this.main_mc_.main.board.text_kanban_title_back:SetVisible(false)
			
			if (genreIdStr == "shop") then
				this.main_mc_:GotoAndStop("main/board/text_kanban_title_song", shopIdStr)
				this.main_mc_:GotoAndStop("main/board/text_song_title_sub", shopIdStr)
				this.main_mc_:GotoAndStop("main/board/text_song_title_ruby", shopIdStr)
			else
				this.main_mc_:GotoAndStop("main/board/text_kanban_title_song", genreIdStr)
				this.main_mc_:GotoAndStop("main/board/text_song_title_sub", genreIdStr)
				this.main_mc_:GotoAndStop("main/board/text_song_title_ruby", genreIdStr)
			end
			
			if (songData.song_id == "back")then
				
				this.main_mc_.main.board.text_kanban_title_back:SetVisible(true)
				this.main_mc_.main.board.text_kanban_title_song:SetVisible(false)
				this.main_mc_.main.board.text_song_title_sub:SetVisible(false)
				this.main_mc_.main.board.text_song_title_ruby:SetVisible(false)
				
				this.main_mc_:GotoAndStop("main/board/text_kanban_title_back", "back")
				this.main_mc_:SetText("main/board/text_kanban_title_back/text_kanban_title_back","text_kanban_title_back","select_"..songData.song_id)
				
				
			-- 楽曲板を閉じている時の楽曲名とサブ表記を入れ替える
			elseif (songData.song_panelCloseDispType == true) then
				
				-- サブ表記
				this.main_mc_:SetText("main/board/text_kanban_title_song/text_kanban_title_song","text_kanban_title_song", songData.song_sub_key)
				-- 楽曲名
				this.main_mc_:SetText("main/board/text_song_title_sub/text_song_title_sub","text_song_title_sub", songData.song_key)
				
			else
				-- 楽曲名
				this.main_mc_:SetText("main/board/text_kanban_title_song/text_kanban_title_song","text_kanban_title_song", songData.song_key)
				-- サブ表記
				this.main_mc_:SetText("main/board/text_song_title_sub/text_song_title_sub","text_song_title_sub", songData.song_sub_key)
			end
			
			-- ルビ
			this.main_mc_:SetText("main/board/text_song_title_ruby/text_song_title_ruby","text_song_title_ruby", songData.song_detail_key)
		
		end,
		
		-- フォーカス時に楽曲名とサブ表記を元に戻す
		SetOpenTypeDispData = function(this, songData)
		
			if (songData.song_panelCloseDispType == true and songData.song_id ~= "back") then
		
				-- 楽曲名
				this.main_mc_:SetText("main/board/text_kanban_title_song/text_kanban_title_song","text_kanban_title_song", songData.song_key)
				-- サブ表記
				this.main_mc_:SetText("main/board/text_song_title_sub/text_song_title_sub","text_song_title_sub", songData.song_sub_key)
				
			end
			
		end,
		
		-- 楽曲板の色指定
		SetSongColor = function(this, songData)
			
			-- とじる看板の時
			if (songData.song_id == "back") then
				this.main_mc_:GotoAndStop("main/board/board_top","back")
				this.main_mc_:GotoAndStop("main/board/board_center","back")
				this.main_mc_:GotoAndStop("main/board/board_bottom","back")
			
			-- ショップフォルダの場合は季節で切り替える必要あり
			elseif (genreIdStr == "shop") then
				this.main_mc_:GotoAndStop("main/board/board_top",shopIdStr)
				this.main_mc_:GotoAndStop("main/board/board_center",shopIdStr)
				this.main_mc_:GotoAndStop("main/board/board_bottom",shopIdStr)
			else
				this.main_mc_:GotoAndStop("main/board/board_top",genreIdStr)
				this.main_mc_:GotoAndStop("main/board/board_center",genreIdStr)
				this.main_mc_:GotoAndStop("main/board/board_bottom",genreIdStr)
			end
			
		end,
		
		--　楽曲購入に失敗したときに色を切り替える
		SetSongNetworkErrorColor = function(this, songData)
		
			if (songData.song_isForShop == true and songData.song_isOpen[1] == false and songData.song_isOpen[2] == false and is_networkError == true) then
				this.main_mc_:GotoAndStop("main/board/board_over_top","on")
				this.main_mc_:GotoAndStop("main/board/board_over_center","on")
				this.main_mc_:GotoAndStop("main/board/board_over_bottom","on")
			else
				this.main_mc_:GotoAndStop("main/board/board_over_top","off")
				this.main_mc_:GotoAndStop("main/board/board_over_center","off")
				this.main_mc_:GotoAndStop("main/board/board_over_bottom","off")
			end
		end,
		
		-- 解放難易度による難易度表示設定
		SetSongOpenLevel = function(this, songData)
			
			if(songData.song_id ~= "back") then
				if (playerOpenLevel[1] == kPlayerOpenOni or playerOpenLevel[2] == kPlayerOpenOni) then
					if (songData.song_isUraOpen[1] == true or songData.song_isUraOpen[2] == true) then 
						this.main_mc_:GotoAndPlay("main/board/song_kanban_info","ura")
					else
						this.main_mc_:GotoAndStop("main/board/song_kanban_info","oni")
					end
				else this.main_mc_:GotoAndStop("main/board/song_kanban_info","default")
				end
			else 
				this.main_mc_:GotoAndStop("main/board/song_kanban_info","none")
			end
		end,
		
		-- 解放難易度による難易度表示設定
		SetSongStar = function(this, songData)
		
			this.main_mc_:GotoAndStop("main/board/song_kanban_info/easy","diff_"..songData:GetStar(1))
			this.main_mc_:GotoAndStop("main/board/song_kanban_info/normal","diff_"..songData:GetStar(2))
			this.main_mc_:GotoAndStop("main/board/song_kanban_info/hard","diff_"..songData:GetStar(3))
			this.main_mc_:GotoAndStop("main/board/song_kanban_info/oni","diff_"..songData:GetStar(4))
			this.main_mc_:GotoAndStop("main/board/song_kanban_info/ura","diff_"..songData:GetStar(5))
			
		end,
		
		-- パパママアイコンの設定
		SetPapaMamaIcon = function(this, songData)
			if(songData.is_papamama == true and player_num < 2) then
				if (optionData_1_ensoSkip == OptionOnOff.kOff and optionData_2_ensoSkip == OptionOnOff.kOff and 
					user_setting_Original_data_[1].ensoSkip == OptionOnOff.kOff and user_setting_Original_data_[2].ensoSkip == OptionOnOff.kOff) then
					
					this.main_mc_:GotoAndStop("main/board/song_kanban_info/easy/support", "on")
					this.main_mc_:SetText("main/board/song_kanban_info/easy/support","text_kanban_support","songselect_papamama_window_text")
				else
					this.main_mc_:GotoAndStop("main/board/song_kanban_info/easy/support", "off")
				end
			else 
				this.main_mc_:GotoAndStop("main/board/song_kanban_info/easy/support", "off")
			end
		end,
		
		-- 難易度名の設定
		SetTextCourseName = function(this)
		
			this.main_mc_:SetText("main/board/song_kanban_info/easy","text_course_easy","course_easy")
			this.main_mc_:SetText("main/board/song_kanban_info/normal","text_course_normal","course_normal")
			this.main_mc_:SetText("main/board/song_kanban_info/hard","text_course_hard","course_hard")
			this.main_mc_:SetText("main/board/song_kanban_info/oni","text_course_oni","course_mania")
			this.main_mc_:SetText("main/board/song_kanban_info/ura","text_course_ura","course_ura")
			
		end,
		
		-- 分岐譜面の表記設定
		SetCourseBranchIcon = function(this, songData)
		
			if (songData.is_branch[1] == true) then this.main_mc_:GotoAndStop("main/board/song_kanban_info/easy/branch", "on") 
			else this.main_mc_:GotoAndStop("main/board/song_kanban_info/easy/branch", "off") end
			if (songData.is_branch[2] == true) then this.main_mc_:GotoAndStop("main/board/song_kanban_info/normal/branch", "on") 
			else this.main_mc_:GotoAndStop("main/board/song_kanban_info/normal/branch", "off") end
			if (songData.is_branch[3] == true) then this.main_mc_:GotoAndStop("main/board/song_kanban_info/hard/branch", "on") 
			else this.main_mc_:GotoAndStop("main/board/song_kanban_info/hard/branch", "off") end
			if (songData.is_branch[4] == true) then this.main_mc_:GotoAndStop("main/board/song_kanban_info/oni/branch", "on") 
			else this.main_mc_:GotoAndStop("main/board/song_kanban_info/oni/branch", "off") end
			if (songData.is_branch[5] == true) then this.main_mc_:GotoAndStop("main/board/song_kanban_info/ura/branch", "on") 
			else this.main_mc_:GotoAndStop("main/board/song_kanban_info/ura/branch", "off") end
			
		end,
		
		-- 王冠の設定
		SetCrown = function(this, songData)
			for playerId = 1, 2 do
				if (songData.panel_genre_id ~= "song") then
					this.main_mc_:GotoAndStop("main/board/crown_"..playerId, "none")
				end
				if (is_CardPlayer[playerId] == true) then
					if (play_data_[playerId].user_data.totalRecordInfo.disp_crown_flag == true) then
					
						if (cardPlayerSelectedCourse[playerId] == EnsoLevelType.kEasy) then
							this:SetEasyCrown(songData, playerId)
						
						elseif (cardPlayerSelectedCourse[playerId] == EnsoLevelType.kNormal) then
							this:SetNormalCrown(songData, playerId)
							
						elseif (cardPlayerSelectedCourse[playerId] == EnsoLevelType.kHard) then
							this:SetHardCrown(songData, playerId)
						
						elseif (cardPlayerSelectedCourse[playerId] == EnsoLevelType.kMania) then
							this:SetOniCrown(songData, playerId)
						
						elseif (cardPlayerSelectedCourse[playerId] == EnsoLevelType.kUra) then
							this:SetUraCrown(songData, playerId)
						end
					end
				end
			end
		end,
		
		-- 王冠（かんたん）の設定
		SetEasyCrown = function(this, songData, playerId)
			if (songData.panel_genre_id == "song") then
				if (songData.record_all_crown[playerId][1] == CrownType.kSilver) then
					this.main_mc_:GotoAndStop("main/board/crown_"..playerId, "clear")
					this.main_mc_:GotoAndStop("main/board/crown_"..playerId.."/clear", "easy")
				elseif (songData.record_all_crown[playerId][1] == CrownType.kGold) then
					this.main_mc_:GotoAndStop("main/board/crown_"..playerId, "fullcombo")
					this.main_mc_:GotoAndStop("main/board/crown_"..playerId.."/fullcombo", "easy")
				
				elseif (songData.record_all_crown[playerId][1] == CrownType.kPerfect) then
					this.main_mc_:GotoAndStop("main/board/crown_"..playerId, "perfect")
					this.main_mc_:GotoAndStop("main/board/crown_"..playerId.."/perfect", "easy")
				else
					this.main_mc_:GotoAndStop("main/board/crown_"..playerId, "none")
					this:SearchAnyCrown(songData, playerId)
				end
			end
		end,
		
		-- 王冠（ふつう）の設定
		SetNormalCrown = function(this, songData, playerId)
			if (songData.panel_genre_id == "song") then
				if (songData.record_all_crown[playerId][2] == CrownType.kSilver) then
					this.main_mc_:GotoAndStop("main/board/crown_"..playerId, "clear")
					this.main_mc_:GotoAndStop("main/board/crown_"..playerId.."/clear", "normal")
				
				elseif (songData.record_all_crown[playerId][2] == CrownType.kGold) then
					this.main_mc_:GotoAndStop("main/board/crown_"..playerId, "fullcombo")
					this.main_mc_:GotoAndStop("main/board/crown_"..playerId.."/fullcombo", "normal")
				
				elseif (songData.record_all_crown[playerId][2] == CrownType.kPerfect) then
					this.main_mc_:GotoAndStop("main/board/crown_"..playerId, "perfect")
					this.main_mc_:GotoAndStop("main/board/crown_"..playerId.."/perfect", "normal")
				else
					this.main_mc_:GotoAndStop("main/board/crown_"..playerId, "none")
					this:SearchAnyCrown(songData, playerId)
				end
			end
		end,

		-- 王冠（むずかしい）の設定
		SetHardCrown = function(this, songData, playerId)
			if (songData.panel_genre_id == "song") then
				if (songData.record_all_crown[playerId][3] == CrownType.kSilver) then
					this.main_mc_:GotoAndStop("main/board/crown_"..playerId, "clear")
					this.main_mc_:GotoAndStop("main/board/crown_"..playerId.."/clear", "hard")
				
				elseif (songData.record_all_crown[playerId][3] == CrownType.kGold) then
					this.main_mc_:GotoAndStop("main/board/crown_"..playerId, "fullcombo")
					this.main_mc_:GotoAndStop("main/board/crown_"..playerId.."/fullcombo", "hard")
				
				elseif (songData.record_all_crown[playerId][3] == CrownType.kPerfect) then
					this.main_mc_:GotoAndStop("main/board/crown_"..playerId, "perfect")
					this.main_mc_:GotoAndStop("main/board/crown_"..playerId.."/perfect", "hard")
				else
					this.main_mc_:GotoAndStop("main/board/crown_"..playerId, "none")
					this:SearchAnyCrown(songData, playerId)
				end
			end
		end,

		-- 王冠（おに）の設定
		SetOniCrown = function(this, songData, playerId)
			if (songData.panel_genre_id == "song") then
				if (songData.record_all_crown[playerId][4] == CrownType.kSilver) then
					this.main_mc_:GotoAndStop("main/board/crown_"..playerId, "clear")
					this.main_mc_:GotoAndStop("main/board/crown_"..playerId.."/clear", "oni")
				
				elseif (songData.record_all_crown[playerId][4] == CrownType.kGold) then
					this.main_mc_:GotoAndStop("main/board/crown_"..playerId, "fullcombo")
					this.main_mc_:GotoAndStop("main/board/crown_"..playerId.."/fullcombo", "oni")
				
				elseif (songData.record_all_crown[playerId][4] == CrownType.kPerfect) then
					this.main_mc_:GotoAndStop("main/board/crown_"..playerId, "perfect")
					this.main_mc_:GotoAndStop("main/board/crown_"..playerId.."/perfect", "oni")
				else
					this.main_mc_:GotoAndStop("main/board/crown_"..playerId, "none")
					this:SearchAnyCrown(songData, playerId)
				end
			end
		end,

		-- 王冠（おに裏）の設定
		SetUraCrown = function(this, songData, playerId)
			if (songData.panel_genre_id == "song") then
				if (songData.record_all_crown[playerId][5] == CrownType.kSilver) then
					this.main_mc_:GotoAndStop("main/board/crown_"..playerId, "clear")
					this.main_mc_:GotoAndStop("main/board/crown_"..playerId.."/clear", "ura")
				
				elseif (songData.record_all_crown[playerId][5] == CrownType.kGold) then
					this.main_mc_:GotoAndStop("main/board/crown_"..playerId, "fullcombo")
					this.main_mc_:GotoAndStop("main/board/crown_"..playerId.."/fullcombo", "ura")
				
				elseif (songData.record_all_crown[playerId][5] == CrownType.kPerfect) then
					this.main_mc_:GotoAndStop("main/board/crown_"..playerId, "perfect")
					this.main_mc_:GotoAndStop("main/board/crown_"..playerId.."/perfect", "ura")
				else
					this.main_mc_:GotoAndStop("main/board/crown_"..playerId, "none")
					this:SearchAnyCrown(songData, playerId)
				end
			end
		end,
		
		-- 指定難易度以外でも王冠を持っていれば表示する
		SearchAnyCrown = function(this, songData, playerId)
			local dispFlag = false
		
			if (songData.panel_genre_id == "song" and songData.song_id ~= "back") then
			
				if (songData.record_all_crown[playerId][1] == CrownType.kSilver) then
					this.main_mc_:GotoAndStop("main/board/crown_"..playerId, "clear")
					this.main_mc_:GotoAndStop("main/board/crown_"..playerId.."/clear", "easy")
					dispFlag = true
				end
				
				if (songData.record_all_crown[playerId][1] == CrownType.kGold) then
					this.main_mc_:GotoAndStop("main/board/crown_"..playerId, "fullcombo")
					this.main_mc_:GotoAndStop("main/board/crown_"..playerId.."/fullcombo", "easy")
					dispFlag = true					
				end

				if (songData.record_all_crown[playerId][1] == CrownType.kPerfect) then
					this.main_mc_:GotoAndStop("main/board/crown_"..playerId, "perfect")
					this.main_mc_:GotoAndStop("main/board/crown_"..playerId.."/perfect", "easy")
					dispFlag = true
				end

				if (songData.record_all_crown[playerId][2] == CrownType.kSilver) then
					this.main_mc_:GotoAndStop("main/board/crown_"..playerId, "clear")
					this.main_mc_:GotoAndStop("main/board/crown_"..playerId.."/clear", "normal")
					dispFlag = true
				end
				
				if (songData.record_all_crown[playerId][2] == CrownType.kGold) then
					this.main_mc_:GotoAndStop("main/board/crown_"..playerId, "fullcombo")
					this.main_mc_:GotoAndStop("main/board/crown_"..playerId.."/fullcombo", "normal")
					dispFlag = true
				end

				if (songData.record_all_crown[playerId][2] == CrownType.kPerfect) then
					this.main_mc_:GotoAndStop("main/board/crown_"..playerId, "perfect")
					this.main_mc_:GotoAndStop("main/board/crown_"..playerId.."/perfect", "normal")
					dispFlag = true
				end

				if (songData.record_all_crown[playerId][3] == CrownType.kSilver) then
					this.main_mc_:GotoAndStop("main/board/crown_"..playerId, "clear")
					this.main_mc_:GotoAndStop("main/board/crown_"..playerId.."/clear", "hard")
					dispFlag = true
				end
				
				if (songData.record_all_crown[playerId][3] == CrownType.kGold) then
					this.main_mc_:GotoAndStop("main/board/crown_"..playerId, "fullcombo")
					this.main_mc_:GotoAndStop("main/board/crown_"..playerId.."/fullcombo", "hard")
					dispFlag = true
				end

				if (songData.record_all_crown[playerId][3] == CrownType.kPerfect) then
					this.main_mc_:GotoAndStop("main/board/crown_"..playerId, "perfect")
					this.main_mc_:GotoAndStop("main/board/crown_"..playerId.."/perfect", "hard")
					dispFlag = true
				end

				if (songData.record_all_crown[playerId][4] == CrownType.kSilver) then
					this.main_mc_:GotoAndStop("main/board/crown_"..playerId, "clear")
					this.main_mc_:GotoAndStop("main/board/crown_"..playerId.."/clear", "oni")
					dispFlag = true
				end
				
				if (songData.record_all_crown[playerId][4] == CrownType.kGold) then
					this.main_mc_:GotoAndStop("main/board/crown_"..playerId, "fullcombo")
					this.main_mc_:GotoAndStop("main/board/crown_"..playerId.."/fullcombo", "oni")
					dispFlag = true
				end

				if (songData.record_all_crown[playerId][4] == CrownType.kPerfect) then
					this.main_mc_:GotoAndStop("main/board/crown_"..playerId, "perfect")
					this.main_mc_:GotoAndStop("main/board/crown_"..playerId.."/perfect", "oni")
					dispFlag = true
				end

				if (songData.record_all_crown[playerId][5] == CrownType.kSilver) then
					this.main_mc_:GotoAndStop("main/board/crown_"..playerId, "clear")
					this.main_mc_:GotoAndStop("main/board/crown_"..playerId.."/clear", "ura")
					dispFlag = true
				end
				
				if (songData.record_all_crown[playerId][5] == CrownType.kGold) then
					this.main_mc_:GotoAndStop("main/board/crown_"..playerId, "fullcombo")
					this.main_mc_:GotoAndStop("main/board/crown_"..playerId.."/fullcombo", "ura")
					dispFlag = true
				end

				if (songData.record_all_crown[playerId][5] == CrownType.kPerfect) then
					this.main_mc_:GotoAndStop("main/board/crown_"..playerId, "perfect")
					this.main_mc_:GotoAndStop("main/board/crown_"..playerId.."/perfect", "ura")
					dispFlag = true
				end
				
				if (dispFlag == false) then
					this.main_mc_:GotoAndStop("main/board/crown_"..playerId, "none")
				end
			end
		end,
		
		-- スコアランクの設定
		SetScoreRank = function(this, songData)
		
			for playerId = 1, 2 do
			
				if (is_CardPlayer[playerId] == true) then
					if (play_data_[playerId].user_data.totalRecordInfo.disp_crown_flag == true) then
						if (songData.record_scoreRank[playerId] == ScoreRank.kIkiWhite) 			then this.main_mc_:GotoAndStop("main/board/rank_"..playerId, "white")
						elseif (songData.record_scoreRank[playerId] == ScoreRank.kIkiSilver) 		then this.main_mc_:GotoAndStop("main/board/rank_"..playerId, "bronze")
						elseif (songData.record_scoreRank[playerId] == ScoreRank.kIkiGold) 			then this.main_mc_:GotoAndStop("main/board/rank_"..playerId, "silver")
						elseif (songData.record_scoreRank[playerId] == ScoreRank.kMiyabiWhite) 		then this.main_mc_:GotoAndStop("main/board/rank_"..playerId, "gold")
						elseif (songData.record_scoreRank[playerId] == ScoreRank.kMiyabiSilver) 	then this.main_mc_:GotoAndStop("main/board/rank_"..playerId, "pink")
						elseif (songData.record_scoreRank[playerId] == ScoreRank.kMiyabiGold) 		then this.main_mc_:GotoAndStop("main/board/rank_"..playerId, "violet")
						elseif (songData.record_scoreRank[playerId] == ScoreRank.kKiwami) 			then this.main_mc_:GotoAndStop("main/board/rank_"..playerId, "rainbow")
						else 																			 this.main_mc_:GotoAndStop("main/board/rank_"..playerId, "none")
						end
					
						if (cardPlayerSelectedCourse[playerId] == EnsoLevelType.kEasy) then

							this.main_mc_:GotoAndStop("main/board/rank_"..playerId.."/white", 	"easy")
							this.main_mc_:GotoAndStop("main/board/rank_"..playerId.."/bronze", 	"easy")
							this.main_mc_:GotoAndStop("main/board/rank_"..playerId.."/silver", 	"easy")
							this.main_mc_:GotoAndStop("main/board/rank_"..playerId.."/gold", 	"easy")
							this.main_mc_:GotoAndStop("main/board/rank_"..playerId.."/pink", 	"easy")
							this.main_mc_:GotoAndStop("main/board/rank_"..playerId.."/violet", 	"easy")
							this.main_mc_:GotoAndStop("main/board/rank_"..playerId.."/rainbow", "easy")
							
						elseif (cardPlayerSelectedCourse[playerId] == EnsoLevelType.kNormal) then

							this.main_mc_:GotoAndStop("main/board/rank_"..playerId.."/white", 	"normal")
							this.main_mc_:GotoAndStop("main/board/rank_"..playerId.."/bronze", 	"normal")
							this.main_mc_:GotoAndStop("main/board/rank_"..playerId.."/silver", 	"normal")
							this.main_mc_:GotoAndStop("main/board/rank_"..playerId.."/gold", 	"normal")
							this.main_mc_:GotoAndStop("main/board/rank_"..playerId.."/pink", 	"normal")
							this.main_mc_:GotoAndStop("main/board/rank_"..playerId.."/violet", 	"normal")
							this.main_mc_:GotoAndStop("main/board/rank_"..playerId.."/rainbow", "normal")
							
						elseif (cardPlayerSelectedCourse[playerId] == EnsoLevelType.kHard) then

							this.main_mc_:GotoAndStop("main/board/rank_"..playerId.."/white", 	"hard")
							this.main_mc_:GotoAndStop("main/board/rank_"..playerId.."/bronze", 	"hard")
							this.main_mc_:GotoAndStop("main/board/rank_"..playerId.."/silver", 	"hard")
							this.main_mc_:GotoAndStop("main/board/rank_"..playerId.."/gold", 	"hard")
							this.main_mc_:GotoAndStop("main/board/rank_"..playerId.."/pink", 	"hard")
							this.main_mc_:GotoAndStop("main/board/rank_"..playerId.."/violet", 	"hard")
							this.main_mc_:GotoAndStop("main/board/rank_"..playerId.."/rainbow", "hard")
							
						elseif (cardPlayerSelectedCourse[playerId] == EnsoLevelType.kMania) then

							this.main_mc_:GotoAndStop("main/board/rank_"..playerId.."/white", 	"oni")
							this.main_mc_:GotoAndStop("main/board/rank_"..playerId.."/bronze", 	"oni")
							this.main_mc_:GotoAndStop("main/board/rank_"..playerId.."/silver", 	"oni")
							this.main_mc_:GotoAndStop("main/board/rank_"..playerId.."/gold", 	"oni")
							this.main_mc_:GotoAndStop("main/board/rank_"..playerId.."/pink", 	"oni")
							this.main_mc_:GotoAndStop("main/board/rank_"..playerId.."/violet", 	"oni")
							this.main_mc_:GotoAndStop("main/board/rank_"..playerId.."/rainbow", "oni")
							
						elseif (cardPlayerSelectedCourse[playerId] == EnsoLevelType.kUra) then
							
							if (songData.record_scoreRank[playerId] ~= nil and songData.record_scoreRank[playerId] >= ScoreRank.kIkiWhite) then
								this.main_mc_:GotoAndStop("main/board/rank_"..playerId.."/white", 	"ura")
								this.main_mc_:GotoAndStop("main/board/rank_"..playerId.."/bronze", 	"ura")
								this.main_mc_:GotoAndStop("main/board/rank_"..playerId.."/silver", 	"ura")
								this.main_mc_:GotoAndStop("main/board/rank_"..playerId.."/gold", 	"ura")
								this.main_mc_:GotoAndStop("main/board/rank_"..playerId.."/pink", 	"ura")
								this.main_mc_:GotoAndStop("main/board/rank_"..playerId.."/violet", 	"ura")
								this.main_mc_:GotoAndStop("main/board/rank_"..playerId.."/rainbow", "ura")

							elseif (songData.record_scoreRank_oni[playerId] ~= nil and songData.record_scoreRank_oni[playerId] >= ScoreRank.kIkiWhite) then
								if (songData.record_scoreRank_oni[playerId] == ScoreRank.kIkiWhite) 			then this.main_mc_:GotoAndStop("main/board/rank_"..playerId, "white")
								elseif (songData.record_scoreRank_oni[playerId] == ScoreRank.kIkiSilver) 		then this.main_mc_:GotoAndStop("main/board/rank_"..playerId, "bronze")
								elseif (songData.record_scoreRank_oni[playerId] == ScoreRank.kIkiGold) 			then this.main_mc_:GotoAndStop("main/board/rank_"..playerId, "silver")
								elseif (songData.record_scoreRank_oni[playerId] == ScoreRank.kMiyabiWhite) 		then this.main_mc_:GotoAndStop("main/board/rank_"..playerId, "gold")
								elseif (songData.record_scoreRank_oni[playerId] == ScoreRank.kMiyabiSilver) 	then this.main_mc_:GotoAndStop("main/board/rank_"..playerId, "pink")
								elseif (songData.record_scoreRank_oni[playerId] == ScoreRank.kMiyabiGold) 		then this.main_mc_:GotoAndStop("main/board/rank_"..playerId, "violet")
								elseif (songData.record_scoreRank_oni[playerId] == ScoreRank.kKiwami) 			then this.main_mc_:GotoAndStop("main/board/rank_"..playerId, "rainbow")
								else 																			 this.main_mc_:GotoAndStop("main/board/rank_"..playerId, "none")
								end

								this.main_mc_:GotoAndStop("main/board/rank_"..playerId.."/white", 	"oni")
								this.main_mc_:GotoAndStop("main/board/rank_"..playerId.."/bronze", 	"oni")
								this.main_mc_:GotoAndStop("main/board/rank_"..playerId.."/silver", 	"oni")
								this.main_mc_:GotoAndStop("main/board/rank_"..playerId.."/gold", 	"oni")
								this.main_mc_:GotoAndStop("main/board/rank_"..playerId.."/pink", 	"oni")
								this.main_mc_:GotoAndStop("main/board/rank_"..playerId.."/violet", 	"oni")
								this.main_mc_:GotoAndStop("main/board/rank_"..playerId.."/rainbow", "oni")
							else 
								this.main_mc_:GotoAndStop("main/board/rank_"..playerId, "none")
							end
						end
					end
				end
			end
		end,
		
		-- キーアイコン表示制御
		SetShopKeyIcon = function(this, songData)
			
			for player = 1, 2 do
				if(songData.song_isForShop == true and songData.song_isOpen[player] == false and songData.song_id ~= "back") then
					if (is_joinPlayer[player] == true) then
						this.main_mc_:GotoAndStop("main/board/lock_normal_"..player, "on")
						this.main_mc_:GotoAndStop("main/board/lock_small_"..player, "on")
					end
				elseif (songData.song_isForShop == false or songData.song_isOpen[player] == true) then
					this.main_mc_:GotoAndStop("main/board/lock_normal_"..player, "off")
					this.main_mc_:GotoAndStop("main/board/lock_small_"..player, "off")				
				end
			end
		end,
		
		-- 必要トークン数の表示制御
		SetShopInfo = function(this, songData)
		
			if(songData.song_isForShop == true and songData.song_id ~= "back") then
				if (songData.song_isOpen[1] == false or songData.song_isOpen[2] == false) then
					if (is_CardPlayer[1] == true or is_CardPlayer[2] == true) then
						if (is_networkError == true) then
							this.main_mc_:GotoAndStop("main/board/shop_info", "error")
							this.main_mc_:SetText("main/board/shop_info/txt_network_error", "txt_network_error", "song_error_info")
						else
							this.main_mc_:GotoAndStop("main/board/shop_info", "on")
							this.main_mc_:GotoAndStop("main/board/shop_info/base", shopIdStr)
							this.main_mc_:SetText("main/board/shop_info/text_song_shop_info", "text_song_shop_info", "song_need_token")
						end
					end
				end
				
				if (songData.song_isOpen[1] == true and songData.song_isOpen[2] == false) then
					if (is_CardPlayer[2] == false) then
						this.main_mc_:GotoAndStop("main/board/shop_info", "off")
						-- Offの時だけ段位の表示
						this:SetDaniInfo(songData)
					end
				elseif (songData.song_isOpen[1] == false and songData.song_isOpen[2] == true) then
					if (is_CardPlayer[1] == false) then
						this.main_mc_:GotoAndStop("main/board/shop_info", "off")
						-- Offの時だけ段位の表示
						this:SetDaniInfo(songData)
					end
				elseif (songData.song_isOpen[1] == true and songData.song_isOpen[2] == true) then
					this.main_mc_:GotoAndStop("main/board/shop_info", "off")
					-- Offの時だけ段位の表示
					this:SetDaniInfo(songData)
				end
			else
				this.main_mc_:GotoAndStop("main/board/shop_info", "off")
				-- Offの時だけ段位の表示
				this:SetDaniInfo(songData)
			end
		end,
		
		--　段位インフォの表示
		SetDaniInfo = function(this, songData)
			if (songData.is_dani == true and songData.song_id ~= "back" and songData.is_dani_icon_disp == true) then		
				this.main_mc_:GotoAndStop("main/board/shop_info", "dani")
				this.main_mc_:GotoAndStop("main/board/shop_info/dani_level", this.tbl_DaniLavel[songData.dani_level])
				this.main_mc_:GotoAndStop("main/board/shop_info/dani_level/course_icon", this.tbl_DaniCourseLevel[songData.dani_course])
			end
		end,
		
		-- アイコンの初期化
		SetSongIcon = function(this, songData)
			
			if (this.main_mc_.main.board.icon:IsPlay() == false) then
				if (songData.song_icon_num >= 2) then 
					this.main_mc_:GotoAndStop("main/board/icon", "wait")
				end
			end
			
			this.main_mc_:GotoAndStop("main/board/icon/icon", "none")
			this:NextSongIcon(songData)
		end,
		
		-- アイコンの表示を次のアイコンに更新
		NextSongIcon = function(this, songData)
			
			-- アイコンの数が1未満なら表示しないあるいは段位課題曲フラグが無ければ一旦消す
			if (songData.song_icon_num < 1 or songData.song_id == "back" or (songData.is_dani == false and songData.is_dani_icon_disp == false)) then 
				this.main_mc_:GotoAndStop("main/board/icon/icon", "none") 
			end
			
			-- 段位アイコンの表示
			if (songData.song_icon_disp_name == "icon_dani" or songData.song_icon_disp_name == "") then
				
				if (songData.is_dani == true and songData.is_dani_icon_disp == true) then
					this.main_mc_:GotoAndStop("main/board/icon/icon", "icon_dani")
					this.main_mc_:GotoAndStop("main/board/icon/icon/dani_level", this.tbl_DaniLavel[songData.dani_level])
					this.main_mc_:GotoAndStop("main/board/icon/icon/dani_level/course_icon", this.tbl_DaniCourseLevel[songData.dani_course])

					if (songData.song_icon_num >= 2) then 
						this:SearchNextIcon("icon_dani", songData)
						return
					end
				else 
					this:SearchNextIcon("icon_dani", songData)
				end
			end
			
			-- newアイコンの表示
			if (songData.song_icon_disp_name == "icon_new" or songData.song_icon_disp_name == "") then
				
				if (songData.song_is_newsong == true) then
					this.main_mc_:GotoAndStop("main/board/icon/icon", "icon_new")
					
					if (songData.song_icon_num >= 2) then this:SearchNextIcon("icon_new", songData)
						return
					end
				else 
					this:SearchNextIcon("icon_new", songData)
				end
			end

			-- パパママアイコンの表示
			if (songData.song_icon_disp_name == "icon_papamama") then
				
				if (songData.is_papamama == true and player_num < 2 and optionData_1_ensoSkip == OptionOnOff.kOff and optionData_2_ensoSkip == OptionOnOff.kOff and 
					user_setting_Original_data_[1].ensoSkip == OptionOnOff.kOff and user_setting_Original_data_[2].ensoSkip == OptionOnOff.kOff) then
					this.main_mc_:GotoAndStop("main/board/icon/icon", "icon_papamama") 
				else this.main_mc_:GotoAndStop("main/board/icon/icon", "none")
				end
				
				if (songData.song_icon_num >= 2) then 
					this:SearchNextIcon("icon_papamama", songData) 
					return
				else 
					this:SearchNextIcon("icon_new", songData)
				end

				if (songData.is_papamama == false or player_num >= 2) then 
					this:SearchNextIcon("icon_papamama", songData)
				end
			end
			
			-- 公式大会アイコンの表示
			if (songData.song_icon_disp_name == "icon_official") then
				
				local officialCompeName = this:SearchOfficialCompe(songData)
				this.main_mc_:GotoAndStop("main/board/icon/icon", officialCompeName)
				
				if (songData.song_icon_num >= 2) then 
					this:SearchNextIcon("icon_official", songData) 
					return
				else 
					this:SearchNextIcon("icon_papamama", songData)
				end

				if (songData.is_officialCompeOne[1] == false and songData.is_officialCompeOne[2] == false) then 
					this:SearchNextIcon("icon_official", songData)
				end
			end
			
			-- ユーザー大会アイコンの表示
			if (songData.song_icon_disp_name == "icon_compe") then
				
				local userCompeName = this:SearchUserCompe(songData)
				this.main_mc_:GotoAndStop("main/board/icon/icon", userCompeName)
				
				if (songData.song_icon_num >= 2) then 
					this:SearchNextIcon("icon_compe", songData) 
					return
				else this:SearchNextIcon("icon_official", songData)
				end
	
				if (songData.is_userCompeOne[1] == false and songData.is_userCompeOne[2] == false) then 
					this:SearchNextIcon("icon_compe", songData)
				end
			end
			
			-- 挑戦状アイコンの表示
			if (songData.song_icon_disp_name == "icon_challenge") then
				
				local challengeName = this:SearchChallenge(songData)		
				this.main_mc_:GotoAndStop("main/board/icon/icon", challengeName)
				
				if (songData.song_icon_num >= 2) then 
					this:SearchNextIcon("icon_challenge", songData)
					return
				else this:SearchNextIcon("icon_compe", songData)
				end

				if (songData.is_challengeOne[1] == false and songData.is_challengeOne[2] == false) then 
					this:SearchNextIcon("icon_challenge", songData)
				end
			end
			
		end,
		
		-- 前に表示したアイコンを元に次に表示するアイコンをセットする
		SearchNextIcon = function(this, beforeIcon, songData)
		
			if (beforeIcon == "") then
			
				if (songData.is_dani == true and songData.is_dani_icon_disp == true) then
					songData.song_icon_disp_name = "icon_dani"
					return
				else beforeIcon = "icon_dani"
				end
			end
			
			if (beforeIcon == "icon_dani") then

				if (songData.song_is_newsong == true) then
					songData.song_icon_disp_name = "icon_new"
					return
				else beforeIcon = "icon_new"
				end
			end

			if (beforeIcon == "icon_new") then

				if (songData.is_papamama == true and player_num < 2 and optionData_1_ensoSkip == OptionOnOff.kOff and optionData_2_ensoSkip == OptionOnOff.kOff and 
					user_setting_Original_data_[1].ensoSkip == OptionOnOff.kOff and user_setting_Original_data_[2].ensoSkip == OptionOnOff.kOff) then
					songData.song_icon_disp_name = "icon_papamama"
					return
				else beforeIcon = "icon_papamama"
				end
			end
			
			if (beforeIcon == "icon_papamama") then				
				
				if (songData.is_officialCompeOne[1] == true or songData.is_officialCompeOne[2] == true) then
					songData.song_icon_disp_name = "icon_official"
					return
				else beforeIcon = "icon_official"
				end
			end
			
			if (beforeIcon == "icon_official") then				
				
				if (songData.is_userCompeOne[1] == true or songData.is_userCompeOne[2] == true) then
					songData.song_icon_disp_name = "icon_compe"
					return
				else beforeIcon = "icon_compe"
				end
			end
			
			if (beforeIcon == "icon_compe") then				
				
				if (songData.is_challengeOne[1] == true or songData.is_challengeOne[2] == true) then
					songData.song_icon_disp_name = "icon_challenge"
					return
				else beforeIcon = "icon_challenge"
				end
			end
			
			if (beforeIcon == "icon_challenge") then
				if (songData.song_is_newsong == true) then
					songData.song_icon_disp_name = "icon_dani"
					return
				else
					songData.song_icon_disp_name = this:SearchIconFirst(songData)
					return
				end
			end
			
		end,
		
		-- ループの最初に表示するアイコンを返す
		SearchIconFirst = function (this, songData)
			
			if (songData.song_is_newsong == true) then
				return "icon_new"
			elseif (songData.is_papamama == true and player_num < 2 and optionData_1_ensoSkip == OptionOnOff.kOff and optionData_2_ensoSkip == OptionOnOff.kOff and 
				user_setting_Original_data_[1].ensoSkip == OptionOnOff.kOff and user_setting_Original_data_[2].ensoSkip == OptionOnOff.kOff) then
				return "icon_papamama"
			elseif (songData.is_officialCompeOne[1] == true or songData.is_officialCompeOne[2] == true) then
				return "icon_official"
			elseif (songData.is_userCompeOne[1] == true or songData.is_userCompeOne[2] == true) then
				return "icon_compe"
			elseif (songData.is_challengeOne[1] == true or songData.is_challengeOne[2] == true) then
				return "icon_challenge"
			else return "icon_dani"
			end
		end,
		
		-- 表示する公式大会アイコンを返す
		SearchOfficialCompe = function(this, songData)
		
			if (songData.is_officialCompeOne[1] == true and songData.is_officialCompeOne[2] == true and player_num >= 2) then
				return "icon_official_03"
			elseif (songData.is_officialCompeOne[1] == true and is_joinPlayer[1] == true) then
				return "icon_official_01"
			else
				return "icon_official_02"
			end
			
		end,
		
		-- 表示するユーザー大会アイコンを返す
		SearchUserCompe = function(this, songData)
		
			if (songData.is_userCompeOne[1] == true and songData.is_userCompeOne[2] == true and player_num >= 2) then
				return "icon_compe_03"
			elseif (songData.is_userCompeOne[1] == true and is_joinPlayer[1] == true) then
				return "icon_compe_01"
			else
				return "icon_compe_02"
			end
			
		end,
		
		-- 表示する挑戦状アイコンを返す
		SearchChallenge = function(this, songData)
		
			if (songData.is_challengeOne[1] == true and songData.is_challengeOne[2] == true and player_num >= 2) then
				return "icon_vs_03"
			elseif (songData.is_challengeOne[1] == true and is_joinPlayer[1] == true) then
				return "icon_vs_01"
			else
				return "icon_vs_02"
			end
			
		end,
		
	}
end

