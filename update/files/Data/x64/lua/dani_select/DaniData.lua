-- 段位選択画面.段位情報Lua
-- Masayuki_Teraoka@al.bandainamco.jp

DaniData = {}

function DaniData.New(dani_lebel_)
	return
	{
		-- 段位お題関連(曲情報)
		musicInfoData				= {},						-- 楽曲の情報
		song_uniqueId 				= {0, 0, 0},				-- 曲ユニークID
		song_id						= {"","",""},				-- 曲ID
		song_difficulty				= {0, 0, 0},				-- 各楽曲の難易度
		song_course_star			= {0, 0, 0},				-- 各楽曲の星の数
		song_genre					= {0, 0, 0},				-- ジャンル名
		song_key					= {"", "", ""},				-- ワードリスト用曲名キー
		song_detail_key				= {"", "", ""},				-- ワードリスト用ルビ曲名キー
		song_isHidden				= {false, false, false},	-- ???対象楽曲か
		song_isOpen					= {false, false, false},	-- プレイヤーがこの楽曲を解放しているか
		
		-- 段位お題関連（段位）
		daniInfoData				= 0,						-- 段位の情報
		dani_level 					= dani_lebel_,				-- 級段位(5級~1級・1段~10段・玄人・名人・超人・達人の19段階)
		dani_name					= "",						-- 段級位名
		clear_level					= 0,						-- クリアレベル（無し・通常クリア・通常フルコンボ・通常ドンダフルコンボ・大成功クリア・大成功フルコンボ・大成功ドンダフルコンボの順）
		arrival_song				= 0,						-- プレイヤーのこの段位の到達曲数（1:1曲目まで,2:2曲目まで,3曲目まで）
		
		-- 段位お題関連（クリア条件）
		theme_genre					= {NormaType.kNone, NormaType.kNone, NormaType.kNone, NormaType.kNone},				-- お題の種類名
		theme_is_continuous			= {false, false, false},	-- 各お題が通しお題かどうか(1つ目、2つ目、3つ目)	
		
		-- ベストスコア関連
		bestscore_soulgauge			= 0,						-- 魂ゲージのベストスコア
		bestscore_quota				= {},						-- 各お題のベストスコア情報を入れる大本の配列
		is_bestscore_get			= false,					-- 既にこの段位のベストスコアを取得して表示までしているか
		is_bestscore_error			= false,					-- ベストスコアの取得がエラー
		
		-- その他
		panel_genre_id				= "",						-- パネルのジャンル名
		
		-- 以下仮パラメータ用
		--song_uniqueId 				= {math.random(100), math.random(100), math.random(100)},			-- 曲ユニークID
		--clear_level					= math.random(6),
		--theme_genre					= {NormaType.kGoodNum, NormaType.kScore, NormaType.kBadNum}, 		-- お題の種類名
		
		SetMusicInfoData = function(this)
			
			for idx = 1, 3 do
			
				this.musicInfoData[idx]         = MusicInfo.create(this.song_uniqueId[idx])
				this.panel_genre_id             = "dani"
				
				this.song_id[idx] 	  		    = this.musicInfoData[idx].id
				this.song_genre[idx]		    = this.musicInfoData[idx].genre
				
				this.song_key[idx]				= this.musicInfoData[idx].song_key
				this.song_detail_key[idx]		= this.musicInfoData[idx].detail_song_key
				this.song_course_star[idx] 	    = this.musicInfoData[idx]:GetStar(this.song_difficulty[idx] -1)				
				
			end
			
			-- 以下仮パラメータ用
			-- this.song_course_star[1]		= math.random(11)
			-- this.song_course_star[2]		= math.random(11)
			-- this.song_course_star[3]		= math.random(11)
			
			-- this.song_difficulty[1]			= math.random(4)
			-- this.song_difficulty[2]			= math.random(4)
			-- this.song_difficulty[3]			= math.random(4)
			
			--this.bestscore_quota_1			= {math.random(100), math.random(100), math.random(100)}
			--this.bestscore_quota_2			= {math.random(100), math.random(100), math.random(100)}
			--this.bestscore_quota_3			= {math.random(100), math.random(100), math.random(100)}
			
		end,
		
		-- 各段位の情報を取得し格納
		SetDaniInfoData = function(this)
			
			this.daniInfoData                   = Cabinet.DaniInfo(this.dani_level)
			this.dani_name                      = this.daniInfoData.title
			
			for idx = 1, 3 do
				this.song_uniqueId[idx] 	    = this.daniInfoData.songs[idx].uid
				this.song_difficulty[idx]	    = this.daniInfoData.songs[idx].course
				this.song_isHidden[idx]			= this.daniInfoData.is_hiddens[idx]
			end
			
			for idx = 1, 4 do
				this.theme_genre[idx]			= this.daniInfoData.borders[idx].cond_type
				this.theme_is_continuous[idx]	= this.daniInfoData.borders[idx].is_gothrough
			end
			
			this.clear_level                    = play_data_.user_data.daniRecordInfo.normal_rank[this.dani_level]
			this.bestscore_soulgauge			= play_data_.user_data.daniRecordInfo.normal_score[this.dani_level].total_gauge
			
			this.bestscore_quota[1]	            = {0,0,0}			-- 1個目のお題の配列(1曲目・2曲目・3曲目)
			this.bestscore_quota[2]	            = {0,0,0}			-- 2個目のお題の配列(1曲目・2曲目・3曲目)
			this.bestscore_quota[3]	            = {0,0,0}			-- 3個目のお題の配列(1曲目・2曲目・3曲目)

		end,
		
		-- 各段位のベストスコアの取得の準備
		SetDaniBestScore = function(this)
			
			Debug.PrintString("SetDaniBestScore")
			
			this.arrival_song = play_data_.user_data.daniRecordInfo.normal_score[this.dani_level].arrival_song_cnt
			--this.arrival_song = 3
			
			-- プレイヤーが該当段位を1回以上遊んでいれば到達曲数に合わせて解放フラグを建てる
			if (this.clear_level > DaniClearRank.kNoPlay) then
				for idx = 1, this.arrival_song do
					this.song_isOpen[idx]			= true
				end
			end
			
			this:SearchSetBestQuota()
			
			if (this:BestScoreZeroJudge() == false) then
				return false
			else
				return true
			end
			
		end,
		
		-- プレイ済みでベストスコアの値が全て0でないならtrue
		BestScoreZeroJudge = function(this)
			if (this.clear_level > DaniClearRank.kNoPlay) then
				for i = 1, 3 do
					for j = 1, 3 do
						if (this.bestscore_quota[i][j] ~= 0) then
							this.is_bestscore_error = false
							return true
						end
					end
				end
				
				if (this.bestscore_soulgauge ~= 0) then
					this.is_bestscore_error = false
					return true
				end
				
				this.is_bestscore_error = true
				return false
			end
		end,
		
		-- 各お題のベストスコアの値を格納
		SearchSetBestQuota = function(this)
			Debug.PrintString("SearchSetBestQuota")
			
			for idx = 1, 3 do
				-- お題が良の時
				if (this.theme_genre[idx + 1] == NormaType.kGoodNum) then
				
					if (this.theme_is_continuous[idx + 1] == false) then
						for i = 1, this.arrival_song do
							this.bestscore_quota[idx][i] = play_data_.user_data.daniRecordInfo.normal_score[this.dani_level].song_score[i].excellent
						end
					else
						
						local total_excellent = 0
						
						for i = 1, this.arrival_song do
							total_excellent = total_excellent + play_data_.user_data.daniRecordInfo.normal_score[this.dani_level].song_score[i].excellent
						end
						
						this.bestscore_quota[idx][1] = total_excellent			
					end
				
				-- お題が可の時
				elseif (this.theme_genre[idx + 1] == NormaType.kOkNum) then
				
					if (this.theme_is_continuous[idx + 1] == false) then
						for i = 1, this.arrival_song do
							this.bestscore_quota[idx][i] = play_data_.user_data.daniRecordInfo.normal_score[this.dani_level].song_score[i].good
						end
					else
					
						local total_good = 0
						
						for i = 1, this.arrival_song do
							total_good = total_good + play_data_.user_data.daniRecordInfo.normal_score[this.dani_level].song_score[i].good
						end
						
						this.bestscore_quota[idx][1] = total_good
					end
				
				-- お題が不可の時
				elseif (this.theme_genre[idx + 1] == NormaType.kBadNum) then
				
					if (this.theme_is_continuous[idx + 1] == false) then
						for i = 1, this.arrival_song do
							this.bestscore_quota[idx][i] = play_data_.user_data.daniRecordInfo.normal_score[this.dani_level].song_score[i].bad
						end
					else
					
						local total_bad = 0
						
						for i = 1, this.arrival_song do
							total_bad = total_bad + play_data_.user_data.daniRecordInfo.normal_score[this.dani_level].song_score[i].bad
						end
						
						this.bestscore_quota[idx][1] = total_bad
					end

				-- お題が最大コンボの時
				elseif (this.theme_genre[idx + 1] == NormaType.kMaxComboNum) then
				
					if (this.theme_is_continuous[idx + 1] == false) then
						for i = 1, this.arrival_song do
							this.bestscore_quota[idx][i] = play_data_.user_data.daniRecordInfo.normal_score[this.dani_level].song_score[i].combo
						end
					else	
						this.bestscore_quota[idx][1] = play_data_.user_data.daniRecordInfo.normal_score[this.dani_level].total_combo
					end

				-- お題が連打の時
				elseif (this.theme_genre[idx + 1] == NormaType.kDramrollNum) then
				
					if (this.theme_is_continuous[idx + 1] == false) then
						for i = 1, this.arrival_song do
							this.bestscore_quota[idx][i] = play_data_.user_data.daniRecordInfo.normal_score[this.dani_level].song_score[i].renda
						end
					else
					
						local total_renda = 0
						
						for i = 1, this.arrival_song do
							total_renda = total_renda + play_data_.user_data.daniRecordInfo.normal_score[this.dani_level].song_score[i].renda
						end
						
						this.bestscore_quota[idx][1] = total_renda
					end

				-- お題がスコアの時
				elseif (this.theme_genre[idx + 1] == NormaType.kScore) then
				
					if (this.theme_is_continuous[idx + 1] == false) then
						for i = 1, this.arrival_song do
							this.bestscore_quota[idx][i] = play_data_.user_data.daniRecordInfo.normal_score[this.dani_level].song_score[i].score
						end
					else
					
						local total_score = 0
						
						for i = 1, this.arrival_song do
							total_score = total_score + play_data_.user_data.daniRecordInfo.normal_score[this.dani_level].song_score[i].score
						end
						
						this.bestscore_quota[idx][1] = total_score
					end

				-- お題が叩いた数の時
				elseif (this.theme_genre[idx + 1] == NormaType.kHitNum) then
					
					if (this.theme_is_continuous[idx + 1] == false) then
						for i = 1, this.arrival_song do
							this.bestscore_quota[idx][i] = play_data_.user_data.daniRecordInfo.normal_score[this.dani_level].song_score[i].hit
						end
					else
					
						local total_hit = 0
						
						for i = 1, this.arrival_song do
							total_hit = total_hit + play_data_.user_data.daniRecordInfo.normal_score[this.dani_level].song_score[i].hit
						end
						
						this.bestscore_quota[idx][1] = total_hit
					end
				end
			end
		end
	}
end
