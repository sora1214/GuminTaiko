-- 曲選択画面.パネル情報Lua
-- Masayuki_Teraoka@al.bandainamco.jp

PanelData = {}

function PanelData.New()
	return
	{
		panel_genre_id				= "",								-- パネルのジャンル名(ジャンル板・曲板・とじる等)

		-- 曲看板関連
		musicInfoData				= {},								-- 楽曲の情報
		song_uniqueId 				= -1,								-- 曲ユニークID
		song_id						= "",								-- 曲ID
		song_order					= 0,								-- 曲並び順番号
		song_genre					= 0,								-- ジャンル名
		song_isServerVisible 		= false,							-- サーバーからの曲表示フラグ
		song_panelCloseDispType		= false,							-- 曲板閉じている時のサブ表記入れ替えフラグ
		song_key					= "",								-- ワードリスト用曲名キー
		song_sub_key				= "",								-- ワードリスト用サブ曲名キー
		song_detail_key				= "",								-- ワードリスト用ルビ曲名キー
		song_bank_name				= "",								-- 曲のバンク名
		song_isOpen					= {false, false},					-- 各プレイヤーがこの楽曲を解放しているか
		song_isUraOpen				= {false, false},					-- 各プレイヤーがおに裏を解放しているか
		song_needOpenToken			= 0,								-- 曲の解放に必要なトークン値
		song_isForShop				= false,							-- 購入対象楽曲かどうか
		song_is_newsong				= false,							-- 新曲対象かどうか
		is_papamama					= false,							--　パパママ対象かどうか
		is_branch					= {false,false,false,false,false},	--　分岐譜面かどうか
		course_star					= {0, 0, 0, 0, 0},					--　各難易度の星の数
		song_icon_num				= 0,								--　表示アイコンの数（パパママ・新曲・挑戦状・大会・段位等）
		song_icon_disp_name			= "",								--　表示アイコンの名称
		
		--　アトリビュート関連
		attributeInfoData			= {},								--　楽曲のアトリビュート情報
		
		-- 大会挑戦状情報(プレイヤーごとになるため二次元配列)
		is_challenge				= {},								-- 挑戦状該当難易度
		is_userCompe				= {},								-- ユーザー大会該当難易度
		is_officialCompe			= {},								-- 公式大会該当難易度
		
		-- ジャン看板関連					
		genreInfoData				= {},								-- ジャンルの情報
		genre_uniqueId 				= -1,								-- ジャンルユニークID
		genre_id					= "",								-- ジャンルID
		genre_order					= 0,								-- ジャンル並び順番号
		genre_vo_toneId				= 0,								-- ボイスのトーンID
		genre_isServerVisible 		= false,							-- サーバーからのジャンル表示フラグ
		
		--　プレイヤーの譜面ごとのスコア関連
		musicRecordInfoData			= {},								-- 譜面ごとのユーザーのプレイ履歴
		record_all_crown			= {},								-- 譜面の王冠(全難易度分の2次元配列)		
		record_scoreRank			= {},								-- 譜面のスコアランク
		record_scoreRank_oni		= {},								-- 譜面のスコアランク(おに)
		
		-- 大会・挑戦状関連					
		is_challengeOne				= {},								-- 挑戦状が一個でも該当するか
		is_userCompeOne				= {},								-- ユーザー大会が一個でも該当するか
		is_officialCompeOne			= {},								-- 公式大会が一個でも該当するか
		
		-- 段位フォルダ関連
		is_dani						= false,							-- 段位課題曲かどうか
		dani_level					= 1,								-- どの段位の課題曲か
		dani_course					= 1,								-- どの難易度が段位課題曲か
		is_dani_icon_disp			= false,							-- この段位のアイコンを表示していいかどうか
		
		-- 曲情報の取得
		SetMusicInfoData = function(this, i)
			
			musicInfoData = MusicInfo.create(tbl_songUniqueId[i])
			
			this.panel_genre_id = "song"
			
			this.song_uniqueId 		        = musicInfoData.unique_id
			this.song_id 	  		        = musicInfoData.id
			this.is_papamama 		        = musicInfoData.is_papamama

			this.song_genre			        = musicInfoData.genre
			
			this.song_key				    = musicInfoData.song_key
			this.song_sub_key			    = musicInfoData.song_sub_key
			this.song_detail_key		    = musicInfoData.detail_song_key
			this.song_bank_name			    = musicInfoData.song_bankname
			
			for i = 1, 5 do
				this.course_star[i] 		= musicInfoData:GetStar((i-1))			
				this.is_branch[i] 			= musicInfoData:IsBranch((i-1))				
			end
			
			this.is_challenge[1]			= {false,false,false,false,false}	-- 挑戦状該当難易度
			this.is_userCompe[1]			= {false,false,false,false,false}	-- ユーザー大会該当難易度
			this.is_officialCompe[1]		= {false,false,false,false,false}	-- 公式大会該当難易度

			this.is_challenge[2]			= {false,false,false,false,false}	-- 挑戦状該当難易度
			this.is_userCompe[2]			= {false,false,false,false,false}	-- ユーザー大会該当難易度
			this.is_officialCompe[2]		= {false,false,false,false,false}	-- 公式大会該当難易度
			
			this:SetChallengeFlag()
			this:SetUserCompeFlag()
			this:SetOfficialCompeFlag()
			
			-- 購入対象楽曲かどうかのフラグを取得する
			if (tbl_is_lock_[i] == true) then
				this.song_isForShop = true
			end
			
			-- サブ表記との入れ替えフラグ
			if (tbl_closeDispType[i] == 1) then
				this.song_panelCloseDispType = true
			end
			
			-- 購入に必要なトークンの値を取得する
			if (needTokenList[i] ~= nil and needTokenList[i] >= 0) then
				this.song_needOpenToken = needTokenList[i]
				Debug.PrintString(needTokenList[i])
			end
			
			-- カードユーザーの有無関係なしに、おに裏の解放状況を取得する
			for idx = 1, 2 do
				this.song_isUraOpen[idx] = PlayDataManager.GetUserOpenUraFlag((idx -1), this.song_uniqueId)
			end
			
			-- 各ユーザーの楽曲の解放状況を取得する
			if (this.song_uniqueId >= 1 and this.genre_uniqueId < 1) then
				if (is_CardPlayer[1] == true) then
					this.song_isOpen[1] = PlayDataManager.IsSongEnableSongSelectPlayer(0, this.song_uniqueId)
				end
				
				if(is_CardPlayer[2] == true) then
					this.song_isOpen[2] = PlayDataManager.IsSongEnableSongSelectPlayer(1, this.song_uniqueId)
				end
			end
			
			-- 段位課題曲かどうか検索
			for idx = 1, #daniMusicList do
				if (this.song_uniqueId == daniMusicList[idx]) then
					this.is_dani = true
					break
				end
			end
			
			-- 課題曲であれば該当段位・難易度を取得する
			if (this.is_dani == true) then
				this.dani_level  = Cabinet.DaniId(this.song_uniqueId)
				this.dani_course = Cabinet.DaniSongLevel(this.song_uniqueId)
				
				if (this.dani_level <= 15) then
					this.is_dani_icon_disp = true
				else
					this.is_dani_icon_disp = PlayDataManager.IsAvailableDaniSongs(this.song_uniqueId)
				end
				
			end
			
			-- アイコンの数を計算する
			this:AddIconNum()
		end,
		
		-- 新曲フラグをアトリビュートから取得する
		SetMusicAttributeData = function(this, i)
		
			attributeInfoData        = MusicAttribute.create(tbl_songUniqueId[i])
			this.song_is_newsong     = attributeInfoData.is_newsong
			
			if (this.song_is_newsong == true) then this.song_icon_num = this.song_icon_num + 1 end
		end,
		
		-- 各難易度の挑戦状フラグを取得する
		SetChallengeFlag = function(this)
			for player = 1, 2 do
				for course_lebel = 1, 5 do
					
					local trackData = ChallengeCompeManager:SearchChallengeData(player, this.song_uniqueId, course_lebel -1)
						
					if (trackData ~= nil) then
						Debug.PrintString(trackData.song_id)
						this.is_challenge[player][course_lebel] = true
						this.is_challengeOne[player]            = true
					end
				end
			end
		end,
		
		-- 各難易度のユーザー大会フラグを取得する
		SetUserCompeFlag = function(this)
			
			for player = 1, 2 do
				for course_lebel = 1, 5 do
				
					local trackData = ChallengeCompeManager:SearchUserCompeData(player, this.song_uniqueId, course_lebel -1)

					if (trackData ~= nil) then
						Debug.PrintString(trackData.song_id)
						this.is_userCompe[player][course_lebel] = true		
						this.is_userCompeOne[player]            = true
					end
				end
			end
		end,

		-- 各難易度の公式大会フラグを取得する
		SetOfficialCompeFlag = function(this)
			
			for player = 1, 2 do
				for course_lebel = 1, 5 do
				
					local trackData = ChallengeCompeManager:SearchOfficialCompeData(player, this.song_uniqueId, course_lebel -1)

					if (trackData ~= nil) then
						Debug.PrintString(trackData.song_id)
						this.is_officialCompe[player][course_lebel] = true
						this.is_officialCompeOne[player]            = true						
					end
				end
			end
		end,

		-- 王冠・スコアランクの記録を取得する
		MusicRecordInfoData = function(this, i)
			
			this.record_all_crown[1] = {CrownType.kNone, CrownType.kNone, CrownType.kNone, CrownType.kNone, CrownType.kNone}
			this.record_all_crown[2] = {CrownType.kNone, CrownType.kNone, CrownType.kNone, CrownType.kNone, CrownType.kNone}
			
			-- おに裏をユーザーが選択している場合
			for playerId = 1, 2 do
				if (cardPlayerSelectedCourse[playerId] == 4) then
					PlayDataManager.SetPlayerHiScoreFromBestScore(playerId -1, tbl_songUniqueId[i], cardPlayerSelectedCourse[playerId] -1)
					this.musicRecordInfoData[playerId]  = PlayDataManager.GetEnsoRecordInfo(playerId -1, tbl_songUniqueId[i], cardPlayerSelectedCourse[playerId] -1)	
					this.record_scoreRank_oni[playerId] = this.musicRecordInfoData[playerId].scoreRank
				end
			end

			for playerId = 1, 2 do
				PlayDataManager.SetPlayerHiScoreFromBestScore(playerId -1, tbl_songUniqueId[i], cardPlayerSelectedCourse[playerId])
				this.musicRecordInfoData[playerId] = PlayDataManager.GetEnsoRecordInfo(playerId -1, tbl_songUniqueId[i], cardPlayerSelectedCourse[playerId])	
				this.record_scoreRank[playerId]    = this.musicRecordInfoData[playerId].scoreRank
			end
			
			this:SetAllLebelCrownInfoData(i)
		end,
		
		-- 開いたフォルダの全譜面の王冠情報を取得するwq
		SetAllLebelCrownInfoData = function(this, i)
		
			for playerId = 1, 2 do
				for course_lebel = 0, 4 do
					this.musicRecordInfoData[playerId]                = PlayDataManager.GetEnsoRecordInfo(playerId -1, tbl_songUniqueId[i], course_lebel)	
					this.record_all_crown[playerId][course_lebel + 1] = this.musicRecordInfoData[playerId].crown
				end
			end
		end,
		
		-- ジャンルデータを取得する
		SetGenreInfoData = function(this, i)
			
			genreInfoData = GenreFolderInfo.create(tbl_genreName[i])
			
			this.genre_uniqueId 			= genreInfoData.unique_id
			this.genre_id 					= genreInfoData.id
			this.genre_order 				= genreInfoData.order
			this.genre_vo_toneId		 	= genreInfoData.vo_toneId
			this.genre_isServerVisible 		= genreInfoData.isServerReleasedFlag
			
			this.song_bank_name				= "bgm_senkyoku_v12a"
			
			if (this.genre_id == "event1")      then this.panel_genre_id = "event"
			elseif (this.genre_id == "event2")  then this.panel_genre_id = "event"
			elseif (this.genre_id == "event3")  then this.panel_genre_id = "event"
			elseif (this.genre_id == "event4")  then this.panel_genre_id = "event"
			elseif (this.genre_id == "event5")  then this.panel_genre_id = "event"
			elseif (this.genre_id == "event6")  then this.panel_genre_id = "event"
			elseif (this.genre_id == "event7")  then this.panel_genre_id = "event"
			elseif (this.genre_id == "event8")  then this.panel_genre_id = "event"
			elseif (this.genre_id == "event9")  then this.panel_genre_id = "event"
			elseif (this.genre_id == "event10") then this.panel_genre_id = "event"
			elseif (this.genre_id == "event11") then this.panel_genre_id = "event"
			elseif (this.genre_id == "event12") then this.panel_genre_id = "event"
			elseif (this.genre_id == "event13") then this.panel_genre_id = "event"
			elseif (this.genre_id == "event14") then this.panel_genre_id = "event"
			elseif (this.genre_id == "event15") then this.panel_genre_id = "event"
			else this.panel_genre_id = "genre"
			end
			
			if (this.genre_id == "favorite")   then this.panel_genre_id = "favorite"
			elseif (this.genre_id == "recent") then this.panel_genre_id = "recent"
			elseif (this.genre_id == "custom") then this.panel_genre_id = "custom"
			elseif (this.genre_id == "dani")   then this.panel_genre_id = "dani"
			elseif (this.genre_id == "shop")   then this.panel_genre_id = "shop"
			end
			
			Debug.PrintString(this.panel_genre_id)

		end,
		
		-- アイコンの数を計算する
		AddIconNum = function(this)
			
			if (this.is_papamama == true) 														then this.song_icon_num = this.song_icon_num + 1 end
			if (this.is_challengeOne[1] == true or this.is_challengeOne[2] == true) 			then this.song_icon_num = this.song_icon_num + 1 end
			if (this.is_officialCompeOne[1] == true or this.is_officialCompeOne[2] == true) 	then this.song_icon_num = this.song_icon_num + 1 end
			if (this.is_userCompeOne[1] == true or this.is_userCompeOne[2] == true) 			then this.song_icon_num = this.song_icon_num + 1 end
			if (this.is_dani == true and this.is_dani_icon_disp == true) 						then this.song_icon_num = this.song_icon_num + 1 end
			
		end,
		
		-- もどる看板の情報をセットする
		SetBackPanelData = function(this)
			
			this.panel_genre_id = "back"
			
			this.song_uniqueId 			 =  99999	-- ユニークID
			this.song_id				 = "back"
			this.song_panelCloseDispType = false
			this.song_bank_name			 = "bgm_senkyoku_v12a"
			this.is_dani				 = false
			
			this.course_star[1] = 0
			this.course_star[2] = 0
			this.course_star[3] = 0
			this.course_star[4] = 0
			this.course_star[5] = 0
			
		end,
		
		-- 難易度の星の数を取得
		GetStar = function(this, level)
			return this.course_star[level]
		end
	}
end
