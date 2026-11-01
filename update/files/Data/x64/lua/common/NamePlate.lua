-- ネームプレート表示
NamePlate = {}
function NamePlate.New(InstanceName)
	return
	{
		instance_name_ = InstanceName,

		LoadMovie = function(this)
			Lumen.LoadMovie("lumen/000_default/common/name_plate",this.instance_name_)
		end,
		-- 初期化
		Setup = function(this)
			if (Lumen.IsLoadMovieFinish() == true) then
				-- ムービークリップ取得
				this.mc_ = Lumen.GetMovieClip(this.instance_name_,true)
				this.plate_mc_ = this.mc_.main
			end
		end,
		-- 表示ON/OFF
		SetVisible = function(this,flag)
			this.mc_:SetVisible(flag)
		end,

		-- プレイヤー情報設定
		-- @param	playerSide		プレイヤー位置（左が1 / 右が2）
		SetPlayerInfo = function(this,playerSide)
			-- ユーザー情報取得
			this.play_data_ = PlayDataManager.GetEntryPlayData((playerSide - 1))

			-- プレイヤー番号
			local playerIndex = playerSide - 1
			if(PlayDataManager.GetEntryUserCount() == 1) then
				playerIndex = 0
			end

			-- 基本的な設定
			this:SetPlayerInfoPlayData(this.play_data_,playerSide,playerIndex,this.play_data_.is_use_credit,"user_name_p"..playerSide,"user_title_p"..playerSide)
		end,

		-- プレイヤー情報設定（エントリー時）
		-- @param	playData		ユーザー情報
		SetPlayerInfoEntry = function(this,playData)
			-- 基本的な設定
			this:SetPlayerInfoPlayData(playData,-1,-1,true,"user_name_entry","user_title_entry")
		end,

		-- プレイヤー情報設定（ユーザー情報から）
		-- @param	playerSide		表示する種別（-2:ＡＩどん/-1:エントリーの中央用/1:左プレイヤー用（赤）/2:右プレイヤー用（青））
		SetPlayerInfoPlayData = function(this,playData,playerSide,playerIdx,useCredit,userName,userTitle)
			-- ベースを決める
			local plate_label = ""

			if(playerSide == -2) then
			-- ＡＩどんちゃん
				plate_label = "ai"

				-- インストールＡＩの場合
--				plate_label = "ai_data"


			elseif(playerSide == -1) then
			-- 中央用
				plate_label = "newentry"
			else
			-- 左右用
				-- 種類（色）
				if(playData.user_type == UserType.kCoin) then
					-- コインユーザー
					plate_label = playerSide.."p_coin"
				else
					-- カードユーザー
					plate_label = playerSide.."p"
				end
			end

			-- 称号、段位表示があるか
			if((playerSide == -2) or (playerSide == -1) or (playData.user_type ~= UserType.kCoin)) then
				-- 称号有り
				if(playData.user_data.title ~= "") then
					plate_label = plate_label.."_shougou"
				end
				-- 段位表示有り
				if((playData.user_data.disp_info.is_disp_dani == true) and (playData.user_data.daniRecordInfo.now_dani > 0)) then
					plate_label = plate_label.."_dani"
				end
			end

			this.plate_mc_:GotoAndStop(plate_label)

			-- 称号の地
			local titlebase_name = {"wood","rainbow","gold","purple","ai_1","ai_2","ai_3","ai_4"}

--	->IDから板のラベルに変換するのは、テーブルじゃない方がいいかもしれないなぁ・・・

			this.plate_mc_.title_instance:GotoAndStop(titlebase_name[(playData.user_data.title_base_id + 1)])
			this.plate_mc_.ai_title_instance:GotoAndStop(titlebase_name[(playData.user_data.title_base_id + 1)])

			-- 段位のクリアレベル
			if(playData.user_data.daniRecordInfo.now_dani > 0) then
				local dani_clear_state = playData.user_data.daniRecordInfo.normal_rank[(playData.user_data.daniRecordInfo.now_dani)]
				if((dani_clear_state == DaniClearRank.kRedClear) or (dani_clear_state == DaniClearRank.kGoldClear)) then
					this.plate_mc_.dani:GotoAndStop("clear")
				end
				if((dani_clear_state == DaniClearRank.kRedFullCombo) or (dani_clear_state == DaniClearRank.kGoldFullCombo)) then
					this.plate_mc_.dani:GotoAndStop("full")
				end
				if((dani_clear_state == DaniClearRank.kRedAllGood) or (dani_clear_state == DaniClearRank.kGoldAllGood)) then
					this.plate_mc_.dani:GotoAndStop("donfull")
				end

				-- 段位
				local dani_label_table = {"5kyuu","4kyuu","3kyuu","2kyuu","1kyuu","1dan","2dan","3dan","4dan","5dan","6dan","7dan","8dan","9dan","10dan","11dan","12dan","13dan","14dan"}
				local dani_label = dani_label_table[(playData.user_data.daniRecordInfo.now_dani)]
				--  ランクアップ用
				this.plate_mc_.rankup_instance.dani_rankup_efc_02_instance:GotoAndStop(dani_label)
				--  通常用
				if((dani_clear_state == DaniClearRank.kRedClear) or (dani_clear_state == DaniClearRank.kRedFullCombo) or (dani_clear_state == DaniClearRank.kRedAllGood)) then
					dani_label = dani_label.."_red"
				end
				if((dani_clear_state == DaniClearRank.kGoldClear) or (dani_clear_state == DaniClearRank.kGoldFullCombo) or (dani_clear_state == DaniClearRank.kGoldAllGood)) then
					dani_label = dani_label.."_gold"
				end
				this.plate_mc_.dani.dani_clear_instance:GotoAndStop(dani_label)
				this.plate_mc_.dani.dani_full_instance:GotoAndStop(dani_label)
				this.plate_mc_.dani.dani_donfull_instance:GotoAndStop(dani_label)
			end

			-- 〇Ｐ
			if(playerIdx < 0) then
				this.plate_mc_.plate_player_no:SetVisible(false)
			else
				this.plate_mc_.plate_player_no:SetVisible(true)
				this.plate_mc_.plate_player_no:GotoAndStop((playerIdx + 1).."p")
			end

			-- グレーアウト
			if(useCredit == true) then
				this.plate_mc_.blank_instance:GotoAndStop("off")
			else
				this.plate_mc_.blank_instance:GotoAndStop("on")
			end

			-- 名前
			this.plate_mc_:SetText("text_name",userName)

			-- 称号
			this.plate_mc_:SetText("text_title",userTitle)
		end,

		-- 昇段演出再生
		PlayDaniRankUpStart = function(this)
			-- ランクアップ表示
			this.plate_mc_.rankup_instance:GotoAndPlay("rankup_start")
		end,
		PlayDaniRankUpEnd = function(this)
			-- ランクアップ表示
			this.plate_mc_.rankup_instance:GotoAndPlay("rankup_end")
		end,
		IsPlayDaniRankUp = function(this)
			-- ランクアップ表示
			return this.plate_mc_.rankup_instance:IsPlay()
		end,

		-- ＡＩどん設定
		SetAIDon = function(this)
			-- ユーザー情報取得
			local playData = PlayDataManager.GetAIDonPlayData()

			-- 通常のＡＩどんちゃん
			this:SetPlayerInfoPlayData(playData,-2,-1,true,"user_name_ai","user_title_ai")
		end,
		
		-- プレイヤー情報設定(AIバトル演奏専用)
		-- @param	playerSide		プレイヤーエントリー位置（左が1 / 右が2）
		SetPlayerInfoAI = function(this,playerSide)
			-- ユーザー情報取得
			this.play_data_ = PlayDataManager.GetEntryPlayData((playerSide - 1))
			-- プレイヤー番号
			local playerIndex = playerSide - 1
			if(PlayDataManager.GetEntryUserCount() == 1) then
				playerIndex = 0
			end
			
			-- 基本的な設定（1P赤表記固定のため、playerSide 1固定）
			this:SetPlayerInfoPlayData(this.play_data_, 1, playerIndex, this.play_data_.is_use_credit, "user_name_p"..playerSide, "user_title_p"..playerSide)
		end,

	}
end

