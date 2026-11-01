-- DaniResultReward.lua
-- 段位リザルト報酬画面
DaniResultReward = {}

-- 使うクラスを読み込む
require("common.Sound")
require("common.State")
require("dani_result.DaniResultRewardPanel")

-- 昇段演出
local ShodanState = {
	Start_				= 0,
	InWait_				= 1,
	DressStartWait_		= 2,
	DressEndWait_		= 3,
	NamePlateStartWait_	= 4,
	NamePlateEndWait_	= 5,
	ShodanWait_			= 6,
	Wait_				= 7,
	OutWait_			= 8,
	End_				= 9,
}

-- 報酬
local PresentState = {
	Start_				= 0,
	RewardStart_		= 1,
	RewardWait_			= 2,
	RewardEnd_			= 3,
	Wait_				= 4,
	End_				= 5,
}

-- 段位フォルダ追加
local FolderState = {
	Start_				= 0,
	Wait_				= 1,
	End_				= 2,
}

-- 最高段位到達
local CongratsState = {
	Start_				= 0,
	Wait_				= 1,
	End_				= 2,
}

-- このクラス
function DaniResultReward.New()
	return
	{
		-- ムービークリップ
		mainMc_,
		namePlate_ = {},		-- ネームプレート
		shoudanMc_,				-- 昇段mc

		-- 定数
		kWaitFolder_	= 180,				-- 段位フォルダ追加画面の待機時間
		kWaitShodan_	= 30*Common.FPS,	-- 昇段演出の待機時間
		kWaitPresent_	= 180,				-- ご褒美演出の待機時間

		-- ごほうび
		player_ = 1,				-- 1pか2pか（右側の太鼓で１人プレイの場合は1pになります。ご注意を）
		isUseRight_ = false,		-- このウィンドウが右側に表示されるか否か
		timer_ = 0,					-- 汎用タイマ
		sequence_ = 0,				-- シーケンス遷移用
		rewardIndex_ = 1,
		targetRewardTokenId_ = 0,	-- 対象とするトークンID（このIDに紐づいたごほうびのみを表示する）
		rewardTypeList_,			-- ごほうびタイプリスト（0：称号、1：きせかえ頭、2：きせかえ体、3：きせかえ顔、4：きせかえプチキャラ、5：きせかえ着ぐるみ、6：楽曲、7：音色）
		rewardUniqueIdList_,		-- ごほうびUIDリスト
		rewardMessageList_,			-- ごほうび獲得条件を指すワードリストのキーリスト（"クリア達成！"とか"フルコンボ達成！"とかを指すキー）
		rewardValueList_,			-- 称号ならレア度、きせかえならファイルID、楽曲か音色なら未使用
		rewardNameKeyList_,			-- ごほうび名を指すワードリストのキーリスト
		rewardTokenIdList_,			-- ごほうびと紐づいたトークンID（1以上が有効なIDで、それ以外はトークンとは関係ないごほうび）
		currentCursorPosition_,		-- 現在のカーソル位置
		nextCursorPosition_,		-- 次のカーソル位置
		currentCostume_,			-- 現在のきせかえ情報
		oldTitle_ = "",				-- 変更前の称号文字列
		oldTitleBaseId_ = 0,		-- 変更前の称号板ID
		isDonSmoke_ = false,		-- マイドンの上に雲が発生しているか否か
		isDecide_ = false,			-- 決定ボタンが押されたか否か
		isEnableMoveCursor_ = false,-- カーソル移動を受け付けているか否か
		isRewardPanelEnd_ = false,	-- ごほうびパネルの全処理が完了したか否か

		-- インスタンス
		daniResultRewardPanel_ = DaniResultRewardPanel.New("DaniResultRewardPanel"),

		-- 変数
		state_ = State.New("DaniResultReward"),

		currentTime_	= 0,		-- 時間
		rewardState_	= 0,		-- ステート

		-- 到達数:到達したステージを記録。１～３。

		--フラグ
		isEnd_ = false,

		Init = function(this, namePlate)
			-- 全体シーケンス
			Debug.PrintString("[DaniResultReward] Init")

			this.namePlate_ = namePlate

			this.state_.func_["Begin"] = function()
				-- 開始
				Debug.PrintString("[DaniResultReward] Begin")
				this.state_:SetState("Loading")
			end

			this.state_.func_["Loading"] = function()
				-- 読み込み待ち

				if(Lumen.IsLoadMovieFinish() == true)then
					Debug.PrintString("[DaniResultReward] Loading Finish")

					-- MovieClip
					this.mainMc_ = Lumen.GetMovieClip("main_mc",true)

					-- 設定
					this:SetUp()
					this:SetNextState()

					return
				end
			end

--			this.state_.func_["Present"] = function()
--				--ごほうび画面の更新
--				if(this.rewardState_ == PresentState.Start_)then
--					-- 開始
--					this.currentTime_ = 0
--					this.mainMc_.present_mc:GotoAndStop("in")
--					this.shoudanMc_:GotoAndPlay("gohoubi_start")
--					TSound:Play("voice_daniresult_v12e","atmos_clear_c")	-- SE
--					this.rewardState_ = PresentState.RewardStart_
--					Debug.PrintString("[DaniResultReward] PresentState.Start_ FInish")
--
--				elseif(this.rewardState_ == PresentState.RewardStart_)then
--					-- ご褒美付与開始
--					if(this.shoudanMc_:IsInCurrentLabelMc("" ,"reward") == false)then
--						-- 演出が終わっていない
--						return
--					end
--					this.shoudanMc_:GotoAndStop("reward")
--
--					Debug.PrintString("[DaniResultReward] PresentState.RewardStart_ FInish")
--					this.rewardState_ = PresentState.RewardWait_
--
--				
--				elseif(this.rewardState_ == PresentState.RewardWait_)then
--					-- ご褒美付与待ち
--					if(this.shoudanMc_:IsInCurrentLabelMc("" ,"wait") == false)then
--						-- 演出が終わっていない
--						return
--					end
--
--					this.daniResultRewardPanel_:Update()
--
--					if(this.daniResultRewardPanel_:GetIsRewardPanelEnd() == true)then
--						this.rewardState_ = PresentState.RewardEnd_
--						Debug.PrintString("[DaniResultReward] PresentState.RewardWait_ FInish")
--					end
--
--				elseif(this.rewardState_ == PresentState.RewardEnd_)then
--					-- ご褒美付与終了
--					if(this.shoudanMc_:IsInCurrentLabelMc("" ,"wait") == false)then
--						-- 演出が終わっていない
--						return
--					end
--
--					Debug.PrintString("[DaniResultReward] PresentState.RewardEnd_  FInish")
--					this.rewardState_ = PresentState.Wait_
--
--				elseif(this.rewardState_ == PresentState.Wait_)then
--					-- 待ち
--					if(this.mainMc_.present_mc:IsInCurrentLabelMc("" ,"wait") == false)then
--						-- 演出が終わっていない
--						return
--					end
--
--					this.currentTime_ = this.currentTime_ + 1
--					if(this.currentTime_ >= this.kWaitPresent_)then
--						Debug.PrintString("[DaniResultReward] PresentState.Wait_  FInish")
--						this.mainMc_.present_mc:GotoAndPlay("out")
--						this.rewardState_ = PresentState.End_
--					end
--
--				elseif(this.rewardState_ == PresentState.End_)then
--					-- 終了
--					if(this.mainMc_.present_mc:IsInCurrentLabelMc("" ,"out") == false)then
--						Debug.PrintString("PresentState.End_")
--						Debug.PrintString("[DaniResultReward] Present Finish")
--						g_isPresent_ = false
--						this:SetNextState()
--					end
--				end
--
--			end
			
			this.state_.func_["Shodan"] = function()
				-- 昇段演出画面の更新

				if(this.rewardState_ == ShodanState.Start_)then
					-- 開始
					Debug.PrintString("ShodanState.Start_")

					if(g_odaiDani_ > g_playerDani_)then
						TSound:Play("voice_daniresult_v12e","advance")			-- Voice:「昇段だドン！」
					end

					this.currentTime_ = 0
					this.mainMc_:GotoAndStop("shodan")
					this.shoudanMc_:GotoAndPlay("shoudan_start")
					TSound:Play("se_daniresult_v12e","advance_intro")		-- SE
					Don.SetLoopAnimation(0,"result_clear_loop",true)

					this.rewardState_ = ShodanState.InWait_

				elseif(this.rewardState_ == ShodanState.InWait_)then
					-- 昇段演出終了待ち
					if(this.shoudanMc_:IsInCurrentLabelMc("" ,"dress_change_start") == false)then
						return
					end

					-- 昇段演出終了

					if(g_odaiDani_ > g_playerDani_)then
						-- 衣装変更が必要な場合
						this.shoudanMc_:GotoAndPlay("dress_change_start")
						TSound:Play("se_daniresult_v12e","advance_costume")				-- SE
						this.rewardState_ = ShodanState.DressStartWait_
					elseif(this:CheckNamePlateChange() == true)then
						-- ネームプレート変更が必要な場合
						-- ネームプレートの段位を昇段させる場合
						this.namePlate_:PlayDaniRankUpStart()
						this.rewardState_ = ShodanState.NamePlateStartWait_
						TSound:Play("se_daniresult_v12e","advance_shogo")	-- SE
					else
						-- 特に変更なし
						this.rewardState_ = ShodanState.Wait_
					end

					Debug.PrintString("ShodanState.InWait_ End")

				elseif(this.rewardState_ == ShodanState.DressStartWait_)then
					-- 衣装替え
					if(this.shoudanMc_:IsInCurrentLabelMc("" ,"dress_change_wait") == false)then
						return
					end

					-- 表示が終わっている
					Debug.PrintString("ShodanState.DressStartWait_ End")

					-- 道場の見た目に着せ替え
					this:ChangeDojoCostume()

					this.shoudanMc_:GotoAndPlay("dress_change_end")
					TSound:Play("voice_daniresult_v12e","advance_costume")			-- Voice:きせかえ「段位道場」も昇段だドン
					this.rewardState_ = ShodanState.DressEndWait_

				elseif(this.rewardState_ == ShodanState.DressEndWait_)then
					-- 着せ替え終了待ち
					if(this.shoudanMc_:IsInCurrentLabelMc("" ,"nameplate_dani_rankup") == false)then
						-- 表示が終わっていない
						return
					end

					-- 着せ替え終わり、ネームプレート昇段演出開始
					Debug.PrintString("ShodanState.DressEndWait_ End")

					if(this:CheckNamePlateChange() == true)then
						-- ネームプレートの段位を昇段させる場合
						this.shoudanMc_:GotoAndStop("nameplate_dani_rankup")
						this.namePlate_:PlayDaniRankUpStart()
						this.rewardState_ = ShodanState.NamePlateStartWait_
						TSound:Play("se_daniresult_v12e","advance_shogo")	-- SE
					else
						-- ネームプレートは変更なし
						this.rewardState_ = ShodanState.Wait_
					end

				elseif(this.rewardState_ == ShodanState.NamePlateStartWait_)then
					-- ネームプレート昇段開始待ち
					if(this.namePlate_:IsPlayDaniRankUp() == true)then
						return
					end

					-- ネームプレートが光っている瞬間
					Debug.PrintString("ShodanState.NamePlateStartWait_ End")

					this:ChangeNamePlateDani()
					this.namePlate_:PlayDaniRankUpEnd()
					this.rewardState_ = ShodanState.NamePlateEndWait_

				elseif(this.rewardState_ == ShodanState.NamePlateEndWait_)then
					-- ネームプレート昇段終了待ち
					if(this.namePlate_:IsPlayDaniRankUp() == true)then
						return
					end

					Debug.PrintString("ShodanState.NamePlateEndWait_ End")
					this.rewardState_ = ShodanState.Wait_

				elseif(this.rewardState_ == ShodanState.Wait_)then
					-- 全表示後の待ち時間
					this.currentTime_ = this.currentTime_ + 1
					if(this.currentTime_ == this.kWaitShodan_ or InputDon() == true)then
						Debug.PrintString("ShodanState.Wait_ End")
						this.currentTime_ = 0
						if(g_isCongrats_ == true)then
							this.rewardState_ = ShodanState.OutWait_
							this.shoudanMc_:GotoAndPlay("shoudan_end")
						else
							this.rewardState_ = ShodanState.End_
						end
					end

				elseif(this.rewardState_ == ShodanState.OutWait_)then
					-- 最高段位合格時、〇〇合格を消す処理
					-- 衣装替え
					if(this.shoudanMc_:IsInCurrentLabelMc("" ,"gohoubi_start") == false)then
						return
					end

					Debug.PrintString("ShodanState.Wait_ End")
					this.rewardState_ = ShodanState.End_
					
				elseif(this.rewardState_ == ShodanState.End_)then
					-- 終了
					Debug.PrintString("[DaniResultReward] Shodan Finish")
					g_isShodan_ = false
					this:SetNextState()
				end
			end

			this.state_.func_["Folder"] = function()
				-- 段位フォルダ追加画面の更新

				if(this.rewardState_ == FolderState.Start_)then
					this.mainMc_.dummy_folder:GotoAndPlay("start")
					this.rewardState_ = FolderState.Wait_
					TSound:Play("voice_daniresult_v12e","add_folder")		-- Voice:「段位道場フォルダが追加されたドン！」

				elseif(this.rewardState_ == FolderState.Wait_)then

					-- 待ち
					if(this.mainMc_.dummy_folder:IsInCurrentLabelMc("" ,"end") == false)then
						-- 演出が終わっていない
						return
					end

					this.currentTime_ = 0
					this.rewardState_ = FolderState.End_
					
				elseif(this.rewardState_ == FolderState.End_)then
					this.currentTime_ = this.currentTime_ + 1
					if(this.currentTime_ == this.kWaitFolder_)then
						Debug.PrintString("[DaniResultReward] Folder Finish")
						this.mainMc_.dummy_folder:GotoAndStop("end")
						g_isFolder_ = false
						this:SetNextState()
					end
				end

			end

			this.state_.func_["Congrat"] = function()
				-- 最高段位到達画面の更新

				if(this.rewardState_ == CongratsState.Start_)then
					Debug.PrintString("[DaniResultReward]Congrat Start_")
					this.mainMc_.dummy_congrats:GotoAndPlay("start")
					this.rewardState_ = FolderState.Wait_
					TSound:Play("voice_common_v12a","glad_c")
					TSound:Play("se_daniresult_v12e","popup_superlative")		-- SE

				elseif(this.rewardState_ == CongratsState.Wait_)then

					-- 待ち
					if(this.mainMc_.dummy_congrats:IsInCurrentLabelMc("" ,"end") == false)then
						-- 演出が終わっていない
						return
					end

					Debug.PrintString("[DaniResultReward]Congrat Wait_　Finish")
					this.currentTime_ = 0
					this.rewardState_ = CongratsState.End_
					
				elseif(this.rewardState_ == CongratsState.End_)then
					this.currentTime_ = this.currentTime_ + 1
					if(this.currentTime_ == this.kWaitFolder_)then
						Debug.PrintString("[DaniResultReward]Congrat Finish")
						this.mainMc_.dummy_congrats:GotoAndStop("end")
						g_isCongrats_ = false
						this:SetNextState()
					end
				end

			end

			this.state_.func_["End"] = function()
				this.isEnd_ = true
			end
		end,

		-- 更新
		Update = function(this)
			-- ステート処理
			this.state_:Update()
		end,

		-- 次の遷移先を設定
		SetNextState = function(this)
			Debug.PrintString("SetNextState")

			if(g_isShodan_ == true)then
				-- 昇段演出
				this.state_:SetState("Shodan")
				this:StartShodan()
				this.rewardState_ = ShodanState.Start_
				return
			end

			if(g_isCongrats_ == true)then
				-- 最高段位到達
				this:StartCongrat()
				this.state_:SetState("Congrat")
				-- this.mainMc_:GotoAndPlay("Folder")
				this.rewardState_ = CongratsState.Start_
				return
			end

--			if(g_isPresent_ == true)then
--				-- ご褒美獲得
--				this.state_:SetState("Present")
--				this:StartPresent()
--				-- this.mainMc_:GotoAndPlay("Present")
--				this.rewardState_ = PresentState.Start_
--				return
--			end

			if(g_isFolder_ == true)then
				-- 段位フォルダ
				this:StartFolder()
				this.state_:SetState("Folder")
				-- this.mainMc_:GotoAndPlay("Folder")
				this.rewardState_ = FolderState.Start_
				return
			end

			this.state_:SetState("End")
		end,

		-- 使用する演出の初期化
		SetUp = function(this)
			Debug.PrintString("SetUp")
			-- mc設定
			this.shoudanMc_ = this.mainMc_.dummy_shoudan
			this.shoudanMc_:GotoAndStop("shoudan_start")

			if(g_isFolder_ == true)then
				-- 段位フォルダ
				this:InitFolder()
			end

			if(g_isShodan_ == true)then
				-- 昇段演出
				this:InitShodan()
			end

			if(g_isCongrats_ == true)then
				-- 最高段位到達演出
				this:InitCongrat()
			end

--			if(g_isPresent_ == true)then
--				-- ご褒美演出
--				this:InitPresent()
--			end
		end,

		-- 段位フォルダの初期化
		InitFolder = function(this)
			Debug.PrintString("InitFolder")
			this.mainMc_.dummy_folder.text_mc:SetText("text01","dani_result_folder")
		end,

		-- 段位フォルダの開始
		StartFolder = function(this)
			Debug.PrintString("StartFolder")
			this.currentTime_ = 0
		end,

		----------------------------------------
		-- 昇段関連

		-- 昇段演出の初期化
		InitShodan = function(this)
			Debug.PrintString("InitShodan")

			-- mc設定
			--this.shoudanMc_ = this.mainMc_.dummy_shoudan
			--this.shoudanMc_:GotoAndStop("shoudan_start")

			-- 合格した段位の設定
			this:SetShodanText()

		end,

		-- 昇段テキストの設定
		SetShodanText = function(this)
			Debug.PrintString("SetShodanText")

			local mc_LL		-- 左側の文字
			local mc_LR
			local mc_RL		-- 右側の文字
			local mc_RR
			local mc_LL_Efc	-- 左側の文字のエフェクト
			local mc_LR_Efc
			local mc_RL_Efc	-- 右側の文字のエフェクト
			local mc_RR_Efc
			local gwtext	-- g_ or w_

			-- 赤合格と金合格で使用mcを分ける
			if(g_odaiResult_ > 3)then
				-- 金合格
				mc_LL = this.mainMc_.dani_shoudan_text_LL_mc.text_Gold_mc
				mc_LR = this.mainMc_.dani_shoudan_text_LR_mc.text_Gold_mc
				mc_RL = this.mainMc_.dani_shoudan_text_RL_mc.text_Gold_mc
				mc_RR = this.mainMc_.dani_shoudan_text_RR_mc.text_Gold_mc
				mc_LL_Efc = this.mainMc_.dani_shoudan_text_LL_Efc_mc.text_Gold_mc
				mc_LR_Efc = this.mainMc_.dani_shoudan_text_LR_Efc_mc.text_Gold_mc
				mc_RL_Efc = this.mainMc_.dani_shoudan_text_RL_Efc_mc.text_Gold_mc
				mc_RR_Efc = this.mainMc_.dani_shoudan_text_RR_Efc_mc.text_Gold_mc

				-- 文字色を金に設定
				this.mainMc_.dani_shoudan_text_LL_mc:GotoAndStop("text_gold")
				this.mainMc_.dani_shoudan_text_LR_mc:GotoAndStop("text_gold")
				this.mainMc_.dani_shoudan_text_RL_mc:GotoAndStop("text_gold")
				this.mainMc_.dani_shoudan_text_RR_mc:GotoAndStop("text_gold")
				this.mainMc_.dani_shoudan_text_LL_Efc_mc:GotoAndStop("text_gold")
				this.mainMc_.dani_shoudan_text_LR_Efc_mc:GotoAndStop("text_gold")
				this.mainMc_.dani_shoudan_text_RL_Efc_mc:GotoAndStop("text_gold")
				this.mainMc_.dani_shoudan_text_RR_Efc_mc:GotoAndStop("text_gold")

				gwtext = "g_"
			else
				-- 赤合格
				mc_LL = this.mainMc_.dani_shoudan_text_LL_mc.text_White_mc
				mc_LR = this.mainMc_.dani_shoudan_text_LR_mc.text_White_mc
				mc_RL = this.mainMc_.dani_shoudan_text_RL_mc.text_White_mc
				mc_RR = this.mainMc_.dani_shoudan_text_RR_mc.text_White_mc
				mc_LL_Efc = this.mainMc_.dani_shoudan_text_LL_Efc_mc.text_White_mc
				mc_LR_Efc = this.mainMc_.dani_shoudan_text_LR_Efc_mc.text_White_mc
				mc_RL_Efc = this.mainMc_.dani_shoudan_text_RL_Efc_mc.text_White_mc
				mc_RR_Efc = this.mainMc_.dani_shoudan_text_RR_Efc_mc.text_White_mc

				-- 文字色を白に設定
				this.mainMc_.dani_shoudan_text_LL_mc:GotoAndStop("text_white")
				this.mainMc_.dani_shoudan_text_LR_mc:GotoAndStop("text_white")
				this.mainMc_.dani_shoudan_text_RL_mc:GotoAndStop("text_white")
				this.mainMc_.dani_shoudan_text_RR_mc:GotoAndStop("text_white")
				this.mainMc_.dani_shoudan_text_LL_Efc_mc:GotoAndStop("text_white")
				this.mainMc_.dani_shoudan_text_LR_Efc_mc:GotoAndStop("text_white")
				this.mainMc_.dani_shoudan_text_RL_Efc_mc:GotoAndStop("text_white")
				this.mainMc_.dani_shoudan_text_RR_Efc_mc:GotoAndStop("text_white")

				gwtext = "w_"
			end

			-- 段位の数字文字
			if(g_odaiDani_ == kDan1dan_)then
				mc_LL:GotoAndStop(gwtext.."11")			-- 初
				mc_LL_Efc:GotoAndStop(gwtext.."11")
			elseif(g_odaiDani_ == kDan1kyuu_)then
				mc_LL:GotoAndStop(gwtext.."01")			-- 一
				mc_LL_Efc:GotoAndStop(gwtext.."01")
			elseif(g_odaiDani_ == kDan2kyuu_ or g_odaiDani_ == kDan2dan_)then
				mc_LL:GotoAndStop(gwtext.."02")			-- 二
				mc_LL_Efc:GotoAndStop(gwtext.."02")
			elseif(g_odaiDani_ == kDan3kyuu_ or g_odaiDani_ == kDan3dan_)then
				mc_LL:GotoAndStop(gwtext.."03")			-- 三
				mc_LL_Efc:GotoAndStop(gwtext.."03")
			elseif(g_odaiDani_ == kDan4kyuu_ or g_odaiDani_ == kDan4dan_)then
				mc_LL:GotoAndStop(gwtext.."04")			-- 四
				mc_LL_Efc:GotoAndStop(gwtext.."04")
			elseif(g_odaiDani_ == kDan5kyuu_ or g_odaiDani_ == kDan5dan_)then
				mc_LL:GotoAndStop(gwtext.."05")			-- 五
				mc_LL_Efc:GotoAndStop(gwtext.."05")
			elseif(g_odaiDani_ == kDan6dan_)then
				mc_LL:GotoAndStop(gwtext.."06")			-- 六	TODO:6~10はまだ文字が無いので仮
				mc_LL_Efc:GotoAndStop(gwtext.."06")
			elseif(g_odaiDani_ == kDan7dan_)then
				mc_LL:GotoAndStop(gwtext.."07")			-- 七
				mc_LL_Efc:GotoAndStop(gwtext.."07")
			elseif(g_odaiDani_ == kDan8dan_)then
				mc_LL:GotoAndStop(gwtext.."08")			-- 八
				mc_LL_Efc:GotoAndStop(gwtext.."08")
			elseif(g_odaiDani_ == kDan9dan_)then
				mc_LL:GotoAndStop(gwtext.."09")			-- 九
				mc_LL_Efc:GotoAndStop(gwtext.."09")
			elseif(g_odaiDani_ == kDan10dan_)then
				mc_LL:GotoAndStop(gwtext.."10")			-- 十
				mc_LL_Efc:GotoAndStop(gwtext.."10")
			elseif(g_odaiDani_ == kDan11dan_)then
				mc_LL:GotoAndStop(gwtext.."14")			-- 玄人
				mc_LL_Efc:GotoAndStop(gwtext.."14")
			elseif(g_odaiDani_ == kDan12dan_)then
				mc_LL:GotoAndStop(gwtext.."15")			-- 名人
				mc_LL_Efc:GotoAndStop(gwtext.."15")
			elseif(g_odaiDani_ == kDan13dan_)then
				mc_LL:GotoAndStop(gwtext.."16")			-- 超人
				mc_LL_Efc:GotoAndStop(gwtext.."16")
			elseif(g_odaiDani_ == kDan14dan_)then
				mc_LL:GotoAndStop(gwtext.."17")			-- 達人
				mc_LL_Efc:GotoAndStop(gwtext.."17")
			end

			-- 左側右の文字
			if(g_odaiDani_ <= kDan1kyuu_)then
				mc_LR:GotoAndStop(gwtext.."12")			-- 級
				mc_LR_Efc:GotoAndStop(gwtext.."12")
			elseif(g_odaiDani_ <= kDan10dan_)then
				mc_LR:GotoAndStop(gwtext.."13")			-- 段
				mc_LR_Efc:GotoAndStop(gwtext.."13")
			else
				mc_LR:GotoAndStop(gwtext.."18")			-- 人
				mc_LR_Efc:GotoAndStop(gwtext.."18")
			end

			-- 合格
			mc_RL:GotoAndStop(gwtext.."19")
			mc_RL_Efc:GotoAndStop(gwtext.."19")
			mc_RR:GotoAndStop(gwtext.."20")
			mc_RR_Efc:GotoAndStop(gwtext.."20")

			-- ローカライズ対応文字(段位によって変更)
			local dani = string.format( "%02d", g_odaiDani_ )
			Debug.PrintString("dani :"..dani)
			this.mainMc_.gaiji_text_01_instance:SetText("text","dani_result_shoudan_sub_"..dani)
			this.mainMc_.gaiji_text_01_instance:SetTextBorderColor("text",0x754c24)
			this.mainMc_.gaiji_text_01_instance:SetVisible(false)
		end,

		-- 昇段演出の開始
		StartShodan = function(this)
			Debug.PrintString("StartShodan")
			this.currentTime_ = 0

			-- ムービークリップ開始
			this.mainMc_:GotoAndStop("shodan")
			this.shoudanMc_.don_1p:GotoAndPlay("framein")
			this.shoudanMc_:GotoAndPlay("shoudan_start")
			this:StartShoudanBG()

			Debug.PrintString("nameplate instance")
			Debug.PrintString(this.namePlate_.instance_name_)
		end,

		-- 昇段演出の背景開始
		StartShoudanBG = function(this)
			Debug.PrintString("StartShoudanBG")

			if(g_odaiResult_ == 1 or g_odaiResult_ == 4)then
				-- 白
				Debug.PrintString("白合格昇段")
				this.shoudanMc_.dani_shoudan_bg_W_instance:GotoAndPlay("start")
			elseif(g_odaiResult_ == 2 or g_odaiResult_ == 5)then
				-- 金
				Debug.PrintString("金合格昇段")
				this.shoudanMc_.dani_shoudan_bg_G_instance:GotoAndPlay("start")
			elseif(g_odaiResult_ == 3 or g_odaiResult_ == 6)then
				-- 虹
				Debug.PrintString("虹合格昇段")
				this.shoudanMc_.dani_shoudan_bg_R_instance:GotoAndPlay("start")
			end
		end,

		-- 段位道場の着せ替え
		ChangeDojoCostume = function(this)
			Debug.PrintString("ChangeDojoCostume")

			local costume = PlayDataManager.GetUserClothes(g_joinSide_-1)
			local cosID = Don.GetDaniKigurumiID(g_odaiDani_)
			--local cosID = 36000 + g_playerDani_ + 1 + 5
			costume.kigurumi	= cosID
			costume.head		= 0
			costume.body		= 0
			costume.face		= 0
			costume.puchi		= 0
			Don.ChangeCostume(0, costume)
			PlayDataManager.SetCostume(g_joinSide_-1, costume)
		end,

		-- ネームプレートを変更するか否か
		CheckNamePlateChange = function(this)
			Debug.PrintString("CheckNamePlateChange")
			Debug.PrintString("g_odaiDani_:"..g_odaiDani_)
			Debug.PrintString("g_playerDani_:"..g_playerDani_)
			local flag = false
			-- ネームプレート表示かつ、挑戦したお題がプレイヤーの最高段位以上の場合
			if(g_dispDani_ == true and g_odaiDani_ >= g_playerDani_)then
				flag = true
			end
			return flag
		end,

		-- ネームプレートの最高段位を更新
		ChangeNamePlateDani = function(this)
			Debug.PrintString("ChangeNamePlateDani")
			
			local daniRecordInfo = PlayDataManager.GetDaniRecordInfo(g_joinSide_-1)
			Debug.PrintString("NowDani = "..daniRecordInfo.now_dani)

			-- 段位情報を更新
			daniRecordInfo.now_dani = g_odaiDani_
			daniRecordInfo.normal_rank[daniRecordInfo.now_dani] = g_odaiResult_+1
			PlayDataManager.SetDaniRecordInfo(g_joinSide_-1, daniRecordInfo)

			-- ネームプレートの更新
			this.namePlate_:SetPlayerInfo(g_joinSide_)
		end,

		-- 昇段関連ここまで
		----------------------------------------

		----------------------------------------
		-- 最高段位到達関連
		-- 最高段位到達の初期化
		InitCongrat = function(this)
			if(g_odaiDani_ == kDan10dan_)then
				this.mainMc_.dummy_congrats.dani_congrats_text_01_mc:SetVisible(true)
				this.mainMc_.dummy_congrats.dani_congrats_text_02_mc:SetVisible(false)
			end

			if(g_odaiDani_ == kDan14dan_)then
				this.mainMc_.dummy_congrats.dani_congrats_text_01_mc:SetVisible(false)
				this.mainMc_.dummy_congrats.dani_congrats_text_02_mc:SetVisible(true)
			end

			Debug.PrintString("InitCongrat")
		end,

		-- 最高段位到達の開始
		StartCongrat = function(this)
			Debug.PrintString("StartCongrat")
			this.currentTime_ = 0
		end,

		-- 最高段位到達ここまで
		----------------------------------------

		----------------------------------------
		-- ご褒美関連
		-- ご褒美獲得の初期化
		InitPresent = function(this)
			Debug.PrintString("InitPresent")
			-- 「プレゼントGETだドン！」テキストの設定
			--this.mainMc_.present_mc.present_set_mc:SetText("tx_present_get","dani_result_present")

			this.daniResultRewardPanel_:Init(this.shoudanMc_, 1, this.namePlate_)
			this.daniResultRewardPanel_:InitControlGuide(this.shoudanMc_.dummy_control_guide_instance)
			this.daniResultRewardPanel_:UpdateRewardPanel(-1, true)
			Debug.PrintString("init ok")
			if(g_joinSide_ == 1)then
				this.oldTitle_ = PlayDataManager.GetUserTitle(0)
				this.oldTitleBaseId_ = PlayDataManager.GetUserTitleBaseId(0)
			else
				this.oldTitle_ = PlayDataManager.GetUserTitle(1)
				this.oldTitleBaseId_ = PlayDataManager.GetUserTitleBaseId(1)	
			end
		end,

		-- ご褒美獲得の開始
		StartPresent = function(this)
			Debug.PrintString("StartPresent")
			this.currentTime_ = 0
		end,

		-- ご褒美関連ここまで
		----------------------------------------

		-- 報酬演出の有無
		IsReward = function(this)
			Debug.PrintString("IsReward")
			-- if(g_isFolder_ == true or g_isShodan_ == true or g_isPresent_ == true)then
			if(g_isFolder_ == true or g_isShodan_ == true)then
				-- 報酬有り
				Debug.PrintString("報酬あり")
				return true
			else
				-- 報酬無し
				Debug.PrintString("報酬なし")
				return false
			end
		end,
	}
end