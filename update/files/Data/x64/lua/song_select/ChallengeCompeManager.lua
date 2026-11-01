-- 曲選択画面.挑戦状・大会用マネージャーLua
-- Masayuki_Teraoka@al.bandainamco.jp

ChallengeCompeManager = {
	
	-- セットアップ
	SetUp = function(this)
		
		this.play_data_ = {}
		
		for idx = 1, 2 do
			-- 二人分のプレイデータを取得する
			this.play_data_[idx] = PlayDataManager.GetEntryPlayData(idx -1)
			this.play_data_[idx] = PlayDataManager.GetEntryPlayData(idx -1)
			
		end
	end,
	
	-- 楽曲のユニークIDから該当する挑戦状がないか取得する
	SearchChallengeData = function(this, player, unique_id, courseLevel)
		
		return (this:SearchCompeTrackData(this.play_data_[player].user_data.challengeCompe.challenge, 
				this.play_data_[player].user_data.challengeCompe.challenge_size , unique_id, courseLevel))
	end,
	
	-- 楽曲のユニークIDから該当するユーザー大会がないか取得する
	SearchUserCompeData = function(this, player, unique_id, courseLevel)

		return (this:SearchCompeTrackData(this.play_data_[player].user_data.challengeCompe.user_compe, 
				this.play_data_[player].user_data.challengeCompe.user_compe_size , unique_id, courseLevel))

	end,
	
	-- 楽曲のユニークIDから該当する公式大会がないか取得する
	SearchOfficialCompeData = function(this, player, unique_id, courseLevel)
		
		return (this:SearchCompeTrackData(this.play_data_[player].user_data.challengeCompe.bng_compe, 
				this.play_data_[player].user_data.challengeCompe.bng_compe_size , unique_id, courseLevel))

	end,
	
	-- 受け取った挑戦状・大会データから
	SearchCompeTrackData = function(this, CompeData, CompeSize, unique_id, courseLevel)
	
		for idx = 1, CompeSize do
			for track = 1, CompeData[idx].trackData_size do
				if (CompeData[idx].trackData[track].song_id == unique_id) then
					if (CompeData[idx].trackData[track].level == courseLevel) then
						return CompeData[idx].trackData[track]
					end
				end
			end
		end
		
		return nil
	end,
}

