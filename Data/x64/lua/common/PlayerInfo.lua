-- プレイヤー情報表示
PlayerInfo = {}
function PlayerInfo.New(InstanceName)
	return
	{
		instance_name_ = InstanceName,
		visible_ = false,
		token_disp_ = false,
		event_token_idx_ = 0,
		token_counter_ = 0,
		best_score_musicid_ = -1,
		best_score_hasura_ = false,
		best_score_level_ = EnsoLevelType.kEasy,
		best_score_counter_ = 0,

		load_seq_ = 0,

		LoadMovie = function(this)
			Lumen.LoadMovie("lumen/000_default/common/player_board",this.instance_name_)
			this.load_seq_ = 1
		end,
		Loading = function(this)
			-- ロードムービーの終了チェック
			if (Lumen.IsLoadMovieFinish() == true) then
				-- 一度メインのムービークリップのロード終了を待つ
				if(this.load_seq_ == 1) then
					-- ムービークリップ取得
					this.mc_ = Lumen.GetMovieClip(this.instance_name_,true)
					this.main_mc_ = this.mc_.main_instance

					-- イベントトークンの部分読み込み
					Lumen.LoadMovie("lumen/000_default/common/player_board_event_token",this.instance_name_.."/main_instance/token_event_instance")

					this.load_seq_ = 2
				elseif(this.load_seq_ == 2) then
					return true
				end
			end
			return false
		end,
		-- 初期化
		Setup = function(this)
			if (Lumen.IsLoadMovieFinish() == true) then
				-- 固定のテキストはここで設定しちゃう
				this.main_mc_.bestscore_instance:SetText("text_score_title","playerboard_scoretitle")

				this.token_disp_ = false
				this.token_counter_ = 0

				this.best_score_musicid_ = -1
				this.best_score_hasura_ = false
				this.best_score_level_ = EnsoLevelType.kEasy
				this.best_score_counter_ = 0
			end
		end,

		-- 表示ON/OFF
		SetVisible = function(this,flag)
			this.mc_:SetVisible(flag)
			this.visible_ = flag
		end,

		-- 更新（必要なら呼ぶ）
		Update = function(this,playerSide)
			-- 表示していない場合はスルー
			if(this.visible_ == false) then
				return
			end

			-- プレイヤー情報の状態を監視
			-- トークン関連
			if(this.token_disp_ == false) then
				if(PlayDataManager.GetUserDataStatus((playerSide - 1)) == UserDataStatus.kAvailable) then
					this.token_disp_ = true
					this.token_counter_ = 0

					this.play_data_ = PlayDataManager.GetEntryPlayData((playerSide - 1))

					-- 最初に表示するイベントトークンのインデックスを設定
					this.event_token_idx_ = 0
					for idx = 2,4 do
						if(this.play_data_.user_data.tokenData[idx].id ~= 0) then
							this.event_token_idx_ = idx
							break
						end
					end

					this:SetTokenInfo(playerSide,this.play_data_,this.event_token_idx_)
				end
			else
				-- トークン表示の更新
				this.token_counter_ = this.token_counter_ + 1
				if(this.token_counter_ >= Common.FPS) then
					this.token_counter_ = 0

					this.play_data_ = PlayDataManager.GetEntryPlayData((playerSide - 1))

					-- イベントトークンの表示対象を更新する
					local work_idx = this.event_token_idx_
					for idx = 1,3 do
						work_idx = work_idx + 1
						if(work_idx > 4) then
							work_idx = 2
						end
						if(this.play_data_.user_data.tokenData[work_idx].id ~= 0) then
							this.event_token_idx_ = work_idx
							break
						end
					end

					this:SetTokenInfo(playerSide,this.play_data_,this.event_token_idx_)
				end
			end

			-- ベストスコアの更新
			if(this.best_score_musicid_ ~= -1) then
				if(this.best_score_hasura_ == true) then
					this.best_score_counter_ = this.best_score_counter_ + 1
					if(this.best_score_counter_ >= (Common.FPS * 1.5)) then
						this.best_score_counter_ = 0

						this.play_data_ = PlayDataManager.GetEntryPlayData((playerSide - 1))
						if(this.play_data_.user_data.disp_info.is_disp_bestscore == false) then
							-- 何もしない
						else
							-- 表示難易度入れ替え
							if(this.best_score_level_ == EnsoLevelType.kMania) then
								this.best_score_level_ = EnsoLevelType.kUra
							else
								this.best_score_level_ = EnsoLevelType.kMania
							end
							this:SetBestScoreInfo(playerSide,this.best_score_musicid_,this.play_data_,this.best_score_level_)
						end
					end
				end
			end
		end,

		-- トークン情報だけ更新する
		UpdateTokenInfo = function(this,playerSide)
			this.play_data_ = PlayDataManager.GetEntryPlayData((playerSide - 1))
			this:SetTokenInfo(playerSide,this.play_data_,this.event_token_idx_)
		end,

		-- 自己ベストスコアだけ更新する
		UpdateBestScoreInfo = function(this,playerSide,musicID)
			this.play_data_ = PlayDataManager.GetEntryPlayData((playerSide - 1))

			if(this.best_score_musicid_ ~= musicID) then
				-- 指定した曲IDが変わった時
				this.best_score_musicid_ = musicID
				this.best_score_level_ = this.play_data_.user_data.disp_info.disp_bestscore_level

				this.best_score_hasura_ = false
				-- 鬼の場合
				if(this.best_score_level_ == EnsoLevelType.kMania) then
					-- 裏の存在チェック
					local musicInfoData = MusicInfo.create(this.best_score_musicid_)
					if((musicInfoData:GetStar(EnsoLevelType.kUra) >= 1) and (PlayDataManager.GetAllUserOpenUraFlag(this.best_score_musicid_) == true)) then
						this.best_score_hasura_ = true
					end
				end
			end

			this:SetBestScoreInfo(playerSide,musicID,this.play_data_,this.best_score_level_)
		end,


		-- プレイヤー情報設定
		-- @param	playerSide		プレイヤー位置（左が1 / 右が2）
		-- @param	musicID			ベストスコアを表示する曲ID（表示しない場合は-1）
		-- @param	levelType		ベストスコアを表示する表示難易度
		SetPlayerInfo = function(this,playerSide,musicID)
			-- ユーザー情報取得
			this.play_data_ = PlayDataManager.GetEntryPlayData((playerSide - 1))

			if(this.play_data_.user_type == UserType.kCard) then
				if(this.play_data_.is_use_credit == true) then
					-- カードユーザー（クレジット消費済み）
					this.mc_:SetVisible(true)
					this:SetPlayerInfoParam(this.play_data_)

					this:SetTokenInfo(playerSide,this.play_data_,this.event_token_idx_)

					this.best_score_musicid_ = -1
					this:UpdateBestScoreInfo(playerSide,musicID)
				else
					-- カードユーザー（まだクレジット消費していない）
					this.mc_:SetVisible(false)
				end
			else
				-- コインユーザー
				this.mc_:SetVisible(false)
			end
		end,

		-- プレイヤー情報設定（エントリー時）
		-- @param	playData		ユーザー情報
		SetPlayerInfoEntry = function(this,playData)
			this:SetPlayerInfoParam(playData)
			this:SetTokenInfo(-1,playData,0)
			this:SetBestScoreInfo(1,-1,playData,EnsoLevelType.kEasy)
		end,

		-- プレイヤー情報設定（ユーザー情報指定）
		-- @param	playData		ユーザー情報
		SetPlayerInfoParam = function(this,playData)
			local levelStr = {"easy","normal","hard","oni","oniura"}

			-- 王冠
			-- 地
			this.main_mc_.player_board_instance.bg_instance:GotoAndStop(levelStr[(playData.user_data.totalRecordInfo.disp_crown_level + 1)])

			if(playData.user_data.totalRecordInfo.disp_crown_flag == true) then
				this.main_mc_.player_board_instance:SetVisible(true)

				-- 各獲得数の数字
				this:SetCounter(this.main_mc_.player_board_instance.num_crown_instance_1,playData.user_data.totalRecordInfo.crown_num[CrownType.kSilver + 1],4)
				this:SetCounter(this.main_mc_.player_board_instance.num_crown_instance_2,playData.user_data.totalRecordInfo.crown_num[CrownType.kGold + 1],4)
				this:SetCounter(this.main_mc_.player_board_instance.num_crown_instance_3,playData.user_data.totalRecordInfo.crown_num[CrownType.kPerfect + 1],4)

				this:SetCounter(this.main_mc_.player_board_instance.num_iki_instance_1,playData.user_data.totalRecordInfo.scorerank_num[ScoreRank.kIkiWhite + 1],4)
				this:SetCounter(this.main_mc_.player_board_instance.num_iki_instance_2,playData.user_data.totalRecordInfo.scorerank_num[ScoreRank.kIkiSilver + 1],4)
				this:SetCounter(this.main_mc_.player_board_instance.num_iki_instance_3,playData.user_data.totalRecordInfo.scorerank_num[ScoreRank.kIkiGold + 1],4)
				this:SetCounter(this.main_mc_.player_board_instance.num_miyabi_instance_1,playData.user_data.totalRecordInfo.scorerank_num[ScoreRank.kMiyabiWhite + 1],4)
				this:SetCounter(this.main_mc_.player_board_instance.num_miyabi_instance_2,playData.user_data.totalRecordInfo.scorerank_num[ScoreRank.kMiyabiSilver + 1],4)
				this:SetCounter(this.main_mc_.player_board_instance.num_miyabi_instance_3,playData.user_data.totalRecordInfo.scorerank_num[ScoreRank.kMiyabiGold + 1],4)
				this:SetCounter(this.main_mc_.player_board_instance.num_kiwami_instance,playData.user_data.totalRecordInfo.scorerank_num[ScoreRank.kKiwami + 1],4)
			else
				this.main_mc_.player_board_instance:SetVisible(false)

				-- 各獲得数の数字
				this:SetCounterBar(this.main_mc_.player_board_instance.num_crown_instance_3,4)
				this:SetCounterBar(this.main_mc_.player_board_instance.num_crown_instance_2,4)
				this:SetCounterBar(this.main_mc_.player_board_instance.num_crown_instance_1,4)

				this:SetCounterBar(this.main_mc_.player_board_instance.num_iki_instance_3,4)
				this:SetCounterBar(this.main_mc_.player_board_instance.num_iki_instance_2,4)
				this:SetCounterBar(this.main_mc_.player_board_instance.num_iki_instance_1,4)
				this:SetCounterBar(this.main_mc_.player_board_instance.num_miyabi_instance_3,4)
				this:SetCounterBar(this.main_mc_.player_board_instance.num_miyabi_instance_2,4)
				this:SetCounterBar(this.main_mc_.player_board_instance.num_miyabi_instance_1,4)
				this:SetCounterBar(this.main_mc_.player_board_instance.num_kiwami_instance,4)
			end
		end,

		-- トークン表示設定
		-- @param	playerSide		プレイヤー位置（左が1 / 右が2）
		-- @param	playData		ユーザー情報
		-- @param	event_idx		イベントトークンのインデックス（2～4）
		SetTokenInfo = function(this,playerSide,playData,event_idx)

			if(playerSide == -1) then
				this.main_mc_.token_instance:SetVisible(false)
				this.main_mc_.token_event_instance:SetVisible(false)
				return
			end

			-- 通常トークン
			if(playData.user_data.tokenData[1].id == 0) then
				this.main_mc_.token_instance:SetVisible(false)
			else
				this.main_mc_.token_instance:SetVisible(true)

				-- 春夏秋冬は通常トークンのID4個でループする前提・・・
-- todo確認
-- 通常トークンの背景は固定？
--				local season_idx = (playData.user_data.tokenData[1].id - 1) % 4 + 1
--				local season_label = {"spring","summer","autumn","winter"}
				local token_label = "id_"..playData.user_data.tokenData[1].id

				-- コンプリート
				if(PlayDataManager.CheckTokenComplete((playerSide - 1),playData.user_data.tokenData[1].id) == true) then
					this.main_mc_.token_instance.num_instance:SetVisible(false)

					-- 背景
					this.main_mc_.token_instance.bg_instance:GotoAndStop(token_label.."_complete")
					this.main_mc_.token_instance.bg_instance:SetText("text_complete","token_complete")
				else
					this.main_mc_.token_instance.num_instance:SetVisible(true)
					this:SetCounter(this.main_mc_.token_instance.num_instance,playData.user_data.tokenData[1].point,3)

					-- 背景
					this.main_mc_.token_instance.bg_instance:GotoAndStop(token_label)
				end
			end

			-- イベントトークン
			if((event_idx < 2) or (event_idx > 4)) then
				this.main_mc_.token_event_instance:SetVisible(false)
			else
				if(playData.user_data.tokenData[event_idx].id == 0) then
					this.main_mc_.token_event_instance:SetVisible(false)
				else
					this.main_mc_.token_event_instance:SetVisible(true)

--					local event_label = {"event1","event2","event3"}
					local token_label = "id_"..playData.user_data.tokenData[event_idx].id

					-- コンプリート
					if(PlayDataManager.CheckTokenComplete((playerSide - 1),playData.user_data.tokenData[event_idx].id) == true) then
						this.main_mc_.token_event_instance.num_instance:SetVisible(false)

						-- 背景
						this.main_mc_.token_event_instance.bg_instance:GotoAndStop(token_label.."_complete")
						this.main_mc_.token_event_instance.bg_instance:SetText("text_complete","token_complete")
					else
						this.main_mc_.token_event_instance.num_instance:SetVisible(true)
						this:SetCounter(this.main_mc_.token_event_instance.num_instance,playData.user_data.tokenData[event_idx].point,3)

						-- 背景
						this.main_mc_.token_event_instance.bg_instance:GotoAndStop(token_label)
					end
				end
			end
		end,

		-- 自己ベストスコア表示設定
		-- @param	playerSide		プレイヤー位置（左が1 / 右が2）
		-- @param	musicID			曲ID（表示しない場合は-1）
		-- @param	playData		ユーザー情報
		-- @param	levelType		表示難易度
		SetBestScoreInfo = function(this,playerSide,musicID,playData,levelType)
			-- musicIDを-1で指定した場合は表示しない / そもそもユーザーの設定で非表示の場合もある
			if((musicID == -1) or (playData.user_data.disp_info.is_disp_bestscore == false)) then
				this.main_mc_.bestscore_instance:SetVisible(false)
			else
				-- ベストスコアを設定する
				PlayDataManager.SetPlayerHiScoreFromBestScore((playerSide - 1),musicID,levelType)

				local recordinfo = PlayDataManager.GetEnsoRecordInfo((playerSide - 1),musicID,levelType)

				this.main_mc_.bestscore_instance:SetVisible(true)

				local levelStr = {"easy","normal","hard","oni","oniura"}
				-- アイコン
				this.main_mc_.bestscore_instance.score_icon_instance:GotoAndStop(levelStr[(levelType + 1)])

				-- スコアの数字
				if(recordinfo.hiScore.userdata_status == UserDataStatus.kAvailable) then
					this:SetCounter(this.main_mc_.bestscore_instance.score_instance,recordinfo.hiScore.score,8)
				else
					this:SetCounter(this.main_mc_.bestscore_instance.score_instance,0,8)
				end
			end
		end,


		SetCounter = function(this,target_mc,number,ketamax)
			local workNum = number
			local ketanum = 0
			local keta = 0
			for idx = 1,ketamax do
				if((workNum > 0) or (idx == 1))then
					ketanum = workNum % 10
					workNum = math.floor((workNum / 10))
					keta = keta + 1

					target_mc["n"..keta.."_ins"]:GotoAndStop("ns_0"..ketanum)
				end
			end
			target_mc:GotoAndStop("bs_"..keta)
		end,
		SetCounterBar = function(this,target_mc,ketamax)
			for idx = 1,ketamax do
				target_mc["n"..idx.."_ins"]:GotoAndStop("ns_none")
			end
			target_mc:GotoAndStop("bs_"..ketamax)
		end,

	}
end

