-- AI曲選択画面.楽曲内容表示クラスLua
-- Masayuki_Teraoka@al.bandainamco.jp

AISongDispData = {}

function AISongDispData.New(iParentMc)
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
		
			if (songData.song_isForShop == true and songData.song_isOpen == false and is_networkError == true) then
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
				if (playerOpenLevel == kPlayerOpenOni) then
					if (songData.song_isUraOpen == true) then 
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
		
			if (songData.panel_genre_id ~= "song") then
				this.main_mc_:GotoAndStop("main/board/crown_1", "none")
			end
			
			if (is_CardPlayer == true) then
				if (play_data_.user_data.totalRecordInfo.disp_crown_flag == true) then
				
					if (cardPlayerSelectedCourse == EnsoLevelType.kEasy) then
						this:SetEasyCrown(songData)
					
					elseif (cardPlayerSelectedCourse == EnsoLevelType.kNormal) then
						this:SetNormalCrown(songData)
						
					elseif (cardPlayerSelectedCourse == EnsoLevelType.kHard) then
						this:SetHardCrown(songData)
					
					elseif (cardPlayerSelectedCourse == EnsoLevelType.kMania) then
						this:SetOniCrown(songData)
					
					elseif (cardPlayerSelectedCourse == EnsoLevelType.kUra) then
						this:SetUraCrown(songData)
					end
				end
			end
		end,
		
		-- 王冠（かんたん）の設定
		SetEasyCrown = function(this, songData)
			if (songData.panel_genre_id == "song") then
				if (songData.record_all_crown[1] == CrownType.kSilver) then
					this.main_mc_:GotoAndStop("main/board/crown_1", "clear")
					this.main_mc_:GotoAndStop("main/board/crown_1/clear", "easy")
				elseif (songData.record_all_crown[1] == CrownType.kGold) then
					this.main_mc_:GotoAndStop("main/board/crown_1", "fullcombo")
					this.main_mc_:GotoAndStop("main/board/crown_1/fullcombo", "easy")
				
				elseif (songData.record_all_crown[1] == CrownType.kPerfect) then
					this.main_mc_:GotoAndStop("main/board/crown_1", "perfect")
					this.main_mc_:GotoAndStop("main/board/crown_1/perfect", "easy")
				else
					this.main_mc_:GotoAndStop("main/board/crown_1", "none")
					this:SearchAnyCrown(songData)
				end
			end
		end,
		
		-- 王冠（ふつう）の設定
		SetNormalCrown = function(this, songData)
			if (songData.panel_genre_id == "song") then
				if (songData.record_all_crown[2] == CrownType.kSilver) then
					this.main_mc_:GotoAndStop("main/board/crown_1", "clear")
					this.main_mc_:GotoAndStop("main/board/crown_1/clear", "normal")
				
				elseif (songData.record_all_crown[2] == CrownType.kGold) then
					this.main_mc_:GotoAndStop("main/board/crown_1", "fullcombo")
					this.main_mc_:GotoAndStop("main/board/crown_1/fullcombo", "normal")
				
				elseif (songData.record_all_crown[2] == CrownType.kPerfect) then
					this.main_mc_:GotoAndStop("main/board/crown_1", "perfect")
					this.main_mc_:GotoAndStop("main/board/crown_1/perfect", "normal")
				else
					this.main_mc_:GotoAndStop("main/board/crown_1", "none")
					this:SearchAnyCrown(songData)
				end
			end
		end,

		-- 王冠（むずかしい）の設定
		SetHardCrown = function(this, songData, playerId)
			if (songData.panel_genre_id == "song") then
				if (songData.record_all_crown[3] == CrownType.kSilver) then
					this.main_mc_:GotoAndStop("main/board/crown_1", "clear")
					this.main_mc_:GotoAndStop("main/board/crown_1/clear", "hard")
				
				elseif (songData.record_all_crown[3] == CrownType.kGold) then
					this.main_mc_:GotoAndStop("main/board/crown_1", "fullcombo")
					this.main_mc_:GotoAndStop("main/board/crown_1/fullcombo", "hard")
				
				elseif (songData.record_all_crown[3] == CrownType.kPerfect) then
					this.main_mc_:GotoAndStop("main/board/crown_1", "perfect")
					this.main_mc_:GotoAndStop("main/board/crown_1/perfect", "hard")
				else
					this.main_mc_:GotoAndStop("main/board/crown_1", "none")
					this:SearchAnyCrown(songData)
				end
			end
		end,

		-- 王冠（おに）の設定
		SetOniCrown = function(this, songData, playerId)
			if (songData.panel_genre_id == "song") then
				if (songData.record_all_crown[4] == CrownType.kSilver) then
					this.main_mc_:GotoAndStop("main/board/crown_1", "clear")
					this.main_mc_:GotoAndStop("main/board/crown_1/clear", "oni")
				
				elseif (songData.record_all_crown[4] == CrownType.kGold) then
					this.main_mc_:GotoAndStop("main/board/crown_1", "fullcombo")
					this.main_mc_:GotoAndStop("main/board/crown_1/fullcombo", "oni")
				
				elseif (songData.record_all_crown[4] == CrownType.kPerfect) then
					this.main_mc_:GotoAndStop("main/board/crown_1", "perfect")
					this.main_mc_:GotoAndStop("main/board/crown_1/perfect", "oni")
				else
					this.main_mc_:GotoAndStop("main/board/crown_1", "none")
					this:SearchAnyCrown(songData)
				end
			end
		end,

		-- 王冠（おに裏）の設定
		SetUraCrown = function(this, songData, playerId)
			if (songData.panel_genre_id == "song") then
				if (songData.record_all_crown[5] == CrownType.kSilver) then
					this.main_mc_:GotoAndStop("main/board/crown_1", "clear")
					this.main_mc_:GotoAndStop("main/board/crown_1/clear", "ura")
				
				elseif (songData.record_all_crown[5] == CrownType.kGold) then
					this.main_mc_:GotoAndStop("main/board/crown_1", "fullcombo")
					this.main_mc_:GotoAndStop("main/board/crown_1/fullcombo", "ura")
				
				elseif (songData.record_all_crown[5] == CrownType.kPerfect) then
					this.main_mc_:GotoAndStop("main/board/crown_1", "perfect")
					this.main_mc_:GotoAndStop("main/board/crown_1/perfect", "ura")
				else
					this.main_mc_:GotoAndStop("main/board/crown_1", "none")
					this:SearchAnyCrown(songData)
				end
			end
		end,
		
		-- 指定難易度以外でも王冠を持っていれば表示する
		SearchAnyCrown = function(this, songData)
			local dispFlag = false
		
			if (songData.panel_genre_id == "song" and songData.song_id ~= "back") then
			
				if (songData.record_all_crown[1] == CrownType.kSilver) then
					this.main_mc_:GotoAndStop("main/board/crown_1", "clear")
					this.main_mc_:GotoAndStop("main/board/crown_1/clear", "easy")
					dispFlag = true
				end
				
				if (songData.record_all_crown[1] == CrownType.kGold) then
					this.main_mc_:GotoAndStop("main/board/crown_1", "fullcombo")
					this.main_mc_:GotoAndStop("main/board/crown_1/fullcombo", "easy")
					dispFlag = true					
				end

				if (songData.record_all_crown[1] == CrownType.kPerfect) then
					this.main_mc_:GotoAndStop("main/board/crown_1", "perfect")
					this.main_mc_:GotoAndStop("main/board/crown_1/perfect", "easy")
					dispFlag = true
				end

				if (songData.record_all_crown[2] == CrownType.kSilver) then
					this.main_mc_:GotoAndStop("main/board/crown_1", "clear")
					this.main_mc_:GotoAndStop("main/board/crown_1/clear", "normal")
					dispFlag = true
				end
				
				if (songData.record_all_crown[2] == CrownType.kGold) then
					this.main_mc_:GotoAndStop("main/board/crown_1", "fullcombo")
					this.main_mc_:GotoAndStop("main/board/crown_1/fullcombo", "normal")
					dispFlag = true
				end

				if (songData.record_all_crown[2] == CrownType.kPerfect) then
					this.main_mc_:GotoAndStop("main/board/crown_1", "perfect")
					this.main_mc_:GotoAndStop("main/board/crown_1/perfect", "normal")
					dispFlag = true
				end

				if (songData.record_all_crown[3] == CrownType.kSilver) then
					this.main_mc_:GotoAndStop("main/board/crown_1", "clear")
					this.main_mc_:GotoAndStop("main/board/crown_1/clear", "hard")
					dispFlag = true
				end
				
				if (songData.record_all_crown[3] == CrownType.kGold) then
					this.main_mc_:GotoAndStop("main/board/crown_1", "fullcombo")
					this.main_mc_:GotoAndStop("main/board/crown_1/fullcombo", "hard")
					dispFlag = true
				end

				if (songData.record_all_crown[3] == CrownType.kPerfect) then
					this.main_mc_:GotoAndStop("main/board/crown_1", "perfect")
					this.main_mc_:GotoAndStop("main/board/crown_1/perfect", "hard")
					dispFlag = true
				end

				if (songData.record_all_crown[4] == CrownType.kSilver) then
					this.main_mc_:GotoAndStop("main/board/crown_1", "clear")
					this.main_mc_:GotoAndStop("main/board/crown_1/clear", "oni")
					dispFlag = true
				end
				
				if (songData.record_all_crown[4] == CrownType.kGold) then
					this.main_mc_:GotoAndStop("main/board/crown_1", "fullcombo")
					this.main_mc_:GotoAndStop("main/board/crown_1/fullcombo", "oni")
					dispFlag = true
				end

				if (songData.record_all_crown[4] == CrownType.kPerfect) then
					this.main_mc_:GotoAndStop("main/board/crown_1", "perfect")
					this.main_mc_:GotoAndStop("main/board/crown_1/perfect", "oni")
					dispFlag = true
				end

				if (songData.record_all_crown[5] == CrownType.kSilver) then
					this.main_mc_:GotoAndStop("main/board/crown_1", "clear")
					this.main_mc_:GotoAndStop("main/board/crown_1/clear", "ura")
					dispFlag = true
				end
				
				if (songData.record_all_crown[5] == CrownType.kGold) then
					this.main_mc_:GotoAndStop("main/board/crown_1", "fullcombo")
					this.main_mc_:GotoAndStop("main/board/crown_1/fullcombo", "ura")
					dispFlag = true
				end

				if (songData.record_all_crown[5] == CrownType.kPerfect) then
					this.main_mc_:GotoAndStop("main/board/crown_1", "perfect")
					this.main_mc_:GotoAndStop("main/board/crown_1/perfect", "ura")
					dispFlag = true
				end
				
				if (dispFlag == false) then
					this.main_mc_:GotoAndStop("main/board/crown_1", "none")
				end
			end
		end,
		
		-- スコアランクの設定
		SetScoreRank = function(this, songData)
		
			if (is_CardPlayer == true) then
				if (play_data_.user_data.totalRecordInfo.disp_crown_flag == true) then
					if (songData.record_scoreRank == ScoreRank.kIkiWhite) 			then this.main_mc_:GotoAndStop("main/board/rank_1", "white")
					elseif (songData.record_scoreRank == ScoreRank.kIkiSilver) 		then this.main_mc_:GotoAndStop("main/board/rank_1", "bronze")
					elseif (songData.record_scoreRank == ScoreRank.kIkiGold) 		then this.main_mc_:GotoAndStop("main/board/rank_1", "silver")
					elseif (songData.record_scoreRank == ScoreRank.kMiyabiWhite) 	then this.main_mc_:GotoAndStop("main/board/rank_1", "gold")
					elseif (songData.record_scoreRank == ScoreRank.kMiyabiSilver) 	then this.main_mc_:GotoAndStop("main/board/rank_1", "pink")
					elseif (songData.record_scoreRank == ScoreRank.kMiyabiGold) 	then this.main_mc_:GotoAndStop("main/board/rank_1", "violet")
					elseif (songData.record_scoreRank == ScoreRank.kKiwami) 		then this.main_mc_:GotoAndStop("main/board/rank_1", "rainbow")
					else 																 this.main_mc_:GotoAndStop("main/board/rank_1", "none")
					end
				
					if (cardPlayerSelectedCourse == EnsoLevelType.kEasy) then

						this.main_mc_:GotoAndStop("main/board/rank_1/white", 	"easy")
						this.main_mc_:GotoAndStop("main/board/rank_1/bronze", 	"easy")
						this.main_mc_:GotoAndStop("main/board/rank_1/silver", 	"easy")
						this.main_mc_:GotoAndStop("main/board/rank_1/gold", 	"easy")
						this.main_mc_:GotoAndStop("main/board/rank_1/pink", 	"easy")
						this.main_mc_:GotoAndStop("main/board/rank_1/violet", 	"easy")
						this.main_mc_:GotoAndStop("main/board/rank_1/rainbow", "easy")
						
					elseif (cardPlayerSelectedCourse == EnsoLevelType.kNormal) then

						this.main_mc_:GotoAndStop("main/board/rank_1/white", 	"normal")
						this.main_mc_:GotoAndStop("main/board/rank_1/bronze", 	"normal")
						this.main_mc_:GotoAndStop("main/board/rank_1/silver", 	"normal")
						this.main_mc_:GotoAndStop("main/board/rank_1/gold", 	"normal")
						this.main_mc_:GotoAndStop("main/board/rank_1/pink", 	"normal")
						this.main_mc_:GotoAndStop("main/board/rank_1/violet", 	"normal")
						this.main_mc_:GotoAndStop("main/board/rank_1/rainbow", "normal")
						
					elseif (cardPlayerSelectedCourse == EnsoLevelType.kHard) then

						this.main_mc_:GotoAndStop("main/board/rank_1/white", 	"hard")
						this.main_mc_:GotoAndStop("main/board/rank_1/bronze", 	"hard")
						this.main_mc_:GotoAndStop("main/board/rank_1/silver", 	"hard")
						this.main_mc_:GotoAndStop("main/board/rank_1/gold", 	"hard")
						this.main_mc_:GotoAndStop("main/board/rank_1/pink", 	"hard")
						this.main_mc_:GotoAndStop("main/board/rank_1/violet", 	"hard")
						this.main_mc_:GotoAndStop("main/board/rank_1/rainbow", "hard")
						
					elseif (cardPlayerSelectedCourse == EnsoLevelType.kMania) then

						this.main_mc_:GotoAndStop("main/board/rank_1/white", 	"oni")
						this.main_mc_:GotoAndStop("main/board/rank_1/bronze", 	"oni")
						this.main_mc_:GotoAndStop("main/board/rank_1/silver", 	"oni")
						this.main_mc_:GotoAndStop("main/board/rank_1/gold", 	"oni")
						this.main_mc_:GotoAndStop("main/board/rank_1/pink", 	"oni")
						this.main_mc_:GotoAndStop("main/board/rank_1/violet", 	"oni")
						this.main_mc_:GotoAndStop("main/board/rank_1/rainbow", "oni")
						
					elseif (cardPlayerSelectedCourse == EnsoLevelType.kUra) then
						
						if (songData.record_scoreRank ~= nil and songData.record_scoreRank >= ScoreRank.kIkiWhite) then
							this.main_mc_:GotoAndStop("main/board/rank_1/white", 	"ura")
							this.main_mc_:GotoAndStop("main/board/rank_1/bronze", 	"ura")
							this.main_mc_:GotoAndStop("main/board/rank_1/silver", 	"ura")
							this.main_mc_:GotoAndStop("main/board/rank_1/gold", 	"ura")
							this.main_mc_:GotoAndStop("main/board/rank_1/pink", 	"ura")
							this.main_mc_:GotoAndStop("main/board/rank_1/violet", 	"ura")
							this.main_mc_:GotoAndStop("main/board/rank_1/rainbow",  "ura")

						elseif (songData.record_scoreRank_oni ~= nil and songData.record_scoreRank_oni >= ScoreRank.kIkiWhite) then
							if (songData.record_scoreRank_oni == ScoreRank.kIkiWhite) 			then this.main_mc_:GotoAndStop("main/board/rank_1", "white")
							elseif (songData.record_scoreRank_oni == ScoreRank.kIkiSilver) 		then this.main_mc_:GotoAndStop("main/board/rank_1", "bronze")
							elseif (songData.record_scoreRank_oni == ScoreRank.kIkiGold) 		then this.main_mc_:GotoAndStop("main/board/rank_1", "silver")
							elseif (songData.record_scoreRank_oni == ScoreRank.kMiyabiWhite) 	then this.main_mc_:GotoAndStop("main/board/rank_1", "gold")
							elseif (songData.record_scoreRank_oni == ScoreRank.kMiyabiSilver) 	then this.main_mc_:GotoAndStop("main/board/rank_1", "pink")
							elseif (songData.record_scoreRank_oni == ScoreRank.kMiyabiGold) 	then this.main_mc_:GotoAndStop("main/board/rank_1", "violet")
							elseif (songData.record_scoreRank_oni == ScoreRank.kKiwami) 		then this.main_mc_:GotoAndStop("main/board/rank_1", "rainbow")
							else 																	 this.main_mc_:GotoAndStop("main/board/rank_1", "none")
							end

							this.main_mc_:GotoAndStop("main/board/rank_1/white", 	"oni")
							this.main_mc_:GotoAndStop("main/board/rank_1/bronze", 	"oni")
							this.main_mc_:GotoAndStop("main/board/rank_1/silver", 	"oni")
							this.main_mc_:GotoAndStop("main/board/rank_1/gold", 	"oni")
							this.main_mc_:GotoAndStop("main/board/rank_1/pink", 	"oni")
							this.main_mc_:GotoAndStop("main/board/rank_1/violet", 	"oni")
							this.main_mc_:GotoAndStop("main/board/rank_1/rainbow",  "oni")
						else 
							this.main_mc_:GotoAndStop("main/board/rank_1", "none")
						end
					end
				end
			end
		end,
		
		-- キーアイコン表示制御
		SetShopKeyIcon = function(this, songData)
			
			if(songData.song_isForShop == true and songData.song_isOpen == false and songData.song_id ~= "back") then
				this.main_mc_:GotoAndStop("main/board/lock_normal_1", "on")
				this.main_mc_:GotoAndStop("main/board/lock_small_1", "on")
			elseif (songData.song_isForShop == false or songData.song_isOpen == true) then
				this.main_mc_:GotoAndStop("main/board/lock_normal_1", "off")
				this.main_mc_:GotoAndStop("main/board/lock_small_1", "off")		
			end
		end,
		
		-- 必要トークン数の表示制御
		SetShopInfo = function(this, songData)
		
			if(songData.song_isForShop == true and songData.song_id ~= "back") then
				if (songData.song_isOpen == false) then
					if (is_CardPlayer == true) then
						if (is_networkError == true) then
							this.main_mc_:GotoAndStop("main/board/shop_info", "error")
							this.main_mc_:SetText("main/board/shop_info/txt_network_error", "txt_network_error", "song_error_info")
						else
							this.main_mc_:GotoAndStop("main/board/shop_info", "on")
							this.main_mc_:GotoAndStop("main/board/shop_info/base", shopIdStr)
							this.main_mc_:SetText("main/board/shop_info/text_song_shop_info", "text_song_shop_info", "song_need_token")
						end
					end
				else
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
			
			-- 公式大会アイコンの表示
			if (songData.song_icon_disp_name == "icon_official") then
				
				local officialCompeName = this:SearchOfficialCompe(songData)
				this.main_mc_:GotoAndStop("main/board/icon/icon", officialCompeName)
				
				if (songData.song_icon_num >= 2) then 
					this:SearchNextIcon("icon_official", songData) 
					return
				else 
					this:SearchNextIcon("icon_new", songData)
				end

				if (songData.is_officialCompeOne == false) then 
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
	
				if (songData.is_userCompeOne == false) then 
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

				if (songData.is_challengeOne == false) then 
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
				
				if (songData.is_officialCompeOne == true) then
					songData.song_icon_disp_name = "icon_official"
					return
				else beforeIcon = "icon_official"
				end
			end
			
			if (beforeIcon == "icon_official") then				
				
				if (songData.is_userCompeOne == true) then
					songData.song_icon_disp_name = "icon_compe"
					return
				else beforeIcon = "icon_compe"
				end
			end
			
			if (beforeIcon == "icon_compe") then				
				
				if (songData.is_challengeOne == true) then
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
			elseif (songData.is_officialCompeOne == true) then
				return "icon_official"
			elseif (songData.is_userCompeOne == true) then
				return "icon_compe"
			elseif (songData.is_challengeOne == true) then
				return "icon_challenge"
			else return "icon_dani"
			end
		end,
		
		-- 表示する公式大会アイコンを返す
		SearchOfficialCompe = function(this, songData)
		
			if (songData.is_officialCompeOne == true) then
				return "icon_official_01"
			end
		end,
		
		-- 表示するユーザー大会アイコンを返す
		SearchUserCompe = function(this, songData)
		
			if (songData.is_userCompeOne == true) then
				return "icon_compe_01"
			end
		end,
		
		-- 表示する挑戦状アイコンを返す
		SearchChallenge = function(this, songData)
		
			if (songData.is_challengeOne == true) then
				return "icon_vs_01"
			end
		end,
		
	}
end

