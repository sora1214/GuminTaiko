-- AI曲選択画面.ショップメインクラスLua
-- Masayuki_Teraoka@al.bandainamco.jp

AISongSelectShopMain = {}
-- 使うクラスを読み込む
require("common.Sound")

function AISongSelectShopMain.New()
	return
	{
		--　ロード
		LoadMovieShopMain = function(this)
			Lumen.LoadMovie("lumen/000_default/enso_ai/song_select/ai_song_select_shop", "shop")
		end,
		
		State_ = State.New("AISongSelectShopMain"),		-- このクラス用のStateクラスを作成
		
		start_cnt 					= 0,				-- お買い物ウィンドウを表示するまでのカウント
		wait_start_cnt 				= 0 * Common.FPS,   -- セットアップが終わってからお買い物ウィンドウを表示するまでのウェイト
		
		need_more_token_cnt 		= 0,				-- トークンが足りなくて買えなかった時の表示が出てからのカウント
		wait_need_more_token_cnt 	= 2 * Common.FPS,	-- トークンが足りなくて買えなかった時の表示が消えるまでのウェイト

		network_cnt 				= 0,				-- サーバーとの通信中の表示が出てからのカウント
		wait_network_cnt 			= 2 * Common.FPS,	-- サーバーとの通信中の表示が消えるまでのウェイト
		
		network_success_cnt 		= 0,				-- サーバーとの通信が成功した時の表示が出てからのカウント
		wait_network_success_cnt 	= 2 * Common.FPS,   -- サーバーとの通信が成功した時の表示が消えるまでのウェイト

		network_error_cnt 			= 0,				-- サーバーとの通信が失敗した時の表示が出てからのカウント
		wait_network_error_cnt 		= 2 * Common.FPS,   -- サーバーとの通信が失敗した時の表示が消えるまでのウェイト

		network_complete_cnt 		= 0,				-- ごほうびの取得コンプリートしたときの表示が出てからのカウント
		wait_network_complete_cnt 	= 2 * Common.FPS,	--　ごほうびの取得コンプリートしたときの表示が消えるまでのウェイト
		
		mc_root                     = 0,				-- ショップのルートムービークリップが入るもの
		resultType                  = 1,				-- 最終的に選択した結果
		
		kResultWaiting			    = 1,				-- 開始待機
		kResultRunning			    = 2,				-- 実行中
		kResultCanseled			    = 3,				-- キャンセルされた（通常曲選択へ戻る)
		kResultDecided			    = 4,				-- 購入した
		
		networkState_ 				= 0,				-- ネットワークのステート
		knetworkWaiting			    = 1,				--　ネットワーク待機状態
		knetworkStart			    = 2,				--　ネットワーク通信開始
		knetworkSuccess			    = 3,				--　ネットワーク通信成功
		krewardComplete			    = 4,				--　全ごほうび獲得
		knetworkError			    = 5,				--　ネットワーク通信失敗
		
		selectIndex 				= 2,				--　現在選択中のインデックス
		decidedIndex 			    = 0,				-- 最終的に決定したインデックス
		
		INPUT_1P_LEFT			    = 1,				-- プレイヤー/左カツ
		INPUT_1P_RIGHT			    = 2,				-- プレイヤー/右カツ
		INPUT_1P_DECIDE			    = 3,				-- プレイヤー/ドン
		INPUT_2P_LEFT			    = 4,				-- プレイヤー/左カツ
		INPUT_2P_RIGHT			    = 5,				-- プレイヤー/右カツ
		INPUT_2P_DECIDE			    = 6,				-- プレイヤー/ドン
		
		kselectYes                  = 1,				--　購入する定数
		kselectNot                  = 2,				--　購入しない定数
		
		is_inputEnable_1p			= false,			-- 1P入力受付可能フラグ 
		is_inputEnable_2p			= false,			-- 2P入力受付可能フラグ 
		
		is_decideSePlay 			= false,			-- 選択後のSE鳴らしたか
		
		is_start	                = false,			--　セットアップ後に購入シーケンスが始まったか
		is_need_more_token_start    = false,			--　トークンが足りない表示が始まったか
		is_network_start            = false,			--　ネットワーク通信が始まったか
		is_network_success_start    = false,			--　ネットワーク通信成功が始まったか
		is_network_error_start      = false,			--　ネットワーク通信失敗が始まったか
		is_network_complete_start   = false,			--　全ごほうび獲得が始まったか
		
		Init = function(this)

			-- ステートマシンを組み立てておく、実際に実行されるのはステート処理を実行するとき
			this.State_.func_["Begin"] = function()
				-- 各種パーツ読み込み
				if (Lumen.IsLoadMovieFinish() == true) then
					this.State_:SetState("Loading")
				end
			end
			
			--　ロード
			this.State_.func_["Loading"] = function()
				if (Lumen.IsLoadMovieFinish() == true) then
					-- ムービークリップ取得
					this.mc_main = Lumen.GetMovieClip("main",true)
					this.mc_root = Lumen.GetMovieClip("main/shop",true)
					this.State_:SetState("SetUp")
				end
			end

			--　各種セットアップ
			this.State_.func_["SetUp"] = function()
				
				if (is_joinPlayer[1] == true) then					
					this:SetInputEnable_1p(true)
				else
					this:SetInputEnable_2p(true)
				end
				
				this.decidedIndex = 0
				this.selectIndex = 2
				
				this:InitCursor()
				this:InitAllShopText()
				
				if (this.is_start == true) then
					this.State_:SetState("StartWait")
				end
			end
			
			--　購入シーケンスの開始前ウェイト
			this.State_.func_["StartWait"]=function()
				if(this:waitCnt() == true) then
					this.State_:SetState("Start")
				end
			end
			
			--　購入シーケンスの開始
			this.State_.func_["Start"] = function()
				--Debug.PrintString("Start")
				
				this.mc_root.main:GotoAndPlay("bg_in")
				this.networkState_ = this.knetworkWaiting
				
				-- 購入に必要なトークンが足りない時
				if (play_data_.user_data.tokenData[1].point < data.song_needOpenToken) then
					-- ビープ音を鳴らす
					this:PlaySeBeep()
					this.State_:SetState("NeedMoreToken")
					return
				end

				this.mc_root.main.window_1:GotoAndPlay("in")
				this.mc_root.main.window_1.panel.select_button.cursor:GotoAndPlay("start")
				this.mc_root.main.window_1.panel:GotoAndStop("dialog_1")
				
				this.State_:SetState("BuySelect")
			end
			
			--　購入に必要なトークンが足りない時
			this.State_.func_["NeedMoreToken"] = function()
				--Debug.PrintString("NeedMoreToken")
				this:SetTextNeedMoreToken()
				
				if (this.is_need_more_token_start == false) then
					this.is_need_more_token_start = true
					this.mc_root.main.window_1:GotoAndPlay("in")
					this.mc_root.main.window_1.panel:GotoAndStop("error")
					this.mc_root.main.window_1.panel.chara_error_instance:Play()
				end
					
				if (this:waitNeedMoreTokenCnt() == true) then
					this.is_need_more_token_start = false
					this.State_:SetState("CancelEnd")
				end
			end
			
			--　購入するか購入しないかの選択シーケンス
			this.State_.func_["BuySelect"] = function()
				--Debug.PrintString("BuySelect")
				
				this:keyInput_1P()
				this:keyInput_2P()
				
				Debug.PrintString(this.selectIndex)
				
				if (this.decidedIndex == this.kselectNot) then
					
					this:SetPlayerInputDisable()

					if (this.is_decideSePlay == false) then 
						this:PlaySeCancel()
						this.is_decideSePlay = true
					end

					if (this:IsEndSelectAnimation() == true) then
						this.State_:SetState("CancelEnd")
						this.is_decideSePlay = false
						return
					end
					
				elseif (this.decidedIndex == this.kselectYes) then
				
					this:SetPlayerInputDisable()
				
					-- ドン音を鳴らす
					if (this.is_decideSePlay == false) then 
						this:PlaySeDon()
						
						-- 読み込みSE
						TSound:Play("se_common_v12a","card_reading_loop")
						this.is_decideSePlay = true
					end
					
					if (this:IsEndSelectAnimation() == true) then
						this.State_:SetState("NetWorkConnect")
						this.is_decideSePlay = false
						return
					end
				end				
			end
			
			--　通信開始シーケンス
			this.State_.func_["NetWorkConnect"] = function()
				--Debug.PrintString("NetWorkConnect")
				
				if (OnCancel == true) then
					this:PlaySeBeep()
					this.State_:SetState("NetWorkError")
					return
				end
				
				this:SetTextNetWorkConnect()
				
				this.networkState_ = this.knetworkStart

				if (this.is_network_start == false) then
					this.is_network_start = true
					
					--　C++側に通信開始を伝える
					CppIsNetWorkStart = true
					reBuyFlag = false
					
					-- 呼び出し側で表示を切り替える
					this.mc_root.main.window_1.panel:GotoAndStop("loading")
					this.mc_root.main.window_1.panel.chara_loading_instance:GotoAndPlay("anim")
				end
				
				--　指定のフレームカウント and C++側からのレスポンスが返ってきた
				if (this:waitNetworkCnt() == true and GetBuyResponse == true) then 
					-- C++側からのフラグで購入出来たかどうかを判断
					if (is_buySuccess_ == true) then
						this.is_network_start = false						
						-- 成功音を鳴らす
						TSound:Play("se_senkyoku_v12a","token_consume")
						this:PlayVoiceGet()
						this.State_:SetState("NetWorkSuccess")
					elseif (is_buySuccess == false) then
						this.is_network_start = false
						
						-- ビープ音を鳴らす
						this:PlaySeBeep()
						this.State_:SetState("NetWorkError")
					end
				end
			end
			
			--　通信成功シーケンス
			this.State_.func_["NetWorkSuccess"] = function()
				--Debug.PrintString("NetWorkSuccess")
				this:SetTextNetWorkConnectSuccess()
				this.networkState_ = this.knetworkSuccess

				if (this.is_network_success_start == false) then
					this.is_network_success_start = true
					this.mc_root.main.window_1.panel:GotoAndStop("success")
					this.mc_root.main.window_1.panel.chara_success_instance:Play()
				end
				
				if (this:waitNetworkSuccessCnt() == true) then
					
					-- 通常トークンのコンプリートチェック
					local rewardComplete = false
					
					if (tokenIndex ~= nil) then
						if (is_joinPlayer[1] == true) then
							rewardComplete = PlayDataManager.CheckTokenComplete(0, play_data_.user_data.tokenData[tokenIndex + 1].id)
						else
							rewardComplete = PlayDataManager.CheckTokenComplete(1, play_data_.user_data.tokenData[tokenIndex + 1].id)
						end
					end
					
					if (rewardComplete == true) then
						-- ごほうびコンプリートSE
						this:PlayVoiceAllGet()
						this.State_:SetState("RewardComplete")
						this.is_network_success_start = false
						return
					end
					
					this.is_network_success_start = false
					this.State_:SetState("SuccessEnd")
				end
			end
			
			-- 通信失敗シーケンス
			this.State_.func_["NetWorkError"] = function()
				--Debug.PrintString("NetWorkError")
				this:SetTextNetWorkConnectError()
				
				this.networkState_ = this.knetworkError
				is_networkError = true
				
				if (this.is_network_error_start == false) then
					this.is_network_error_start = true
					this.mc_root.main.window_1.panel:GotoAndStop("error")
					this.mc_root.main.window_1.panel.chara_error_instance:Play()
				end
				
				if (this:waitNetworkErrorCnt() == true) then 
					this.is_network_error_start = false
					this.State_:SetState("ErrorEnd")
				end
			end
			
			-- 全ご褒美獲得シーケンス
			this.State_.func_["RewardComplete"] = function()
				--Debug.PrintString("RewardComplete")
				this:SetTextNetWorkConnectComplete()

				this.networkState_ = this.krewardComplete

				if (this.is_network_complete_start == false) then
					this.is_network_complete_start = true
					this.mc_root.main.window_1.panel:GotoAndStop(shopIdStr)
					this.mc_root.main.window_1.panel.chara_error_instance:Play()
				end
				
				if (this:waitRewardCompleteCnt() == true) then 
					this.is_network_complete_start = false
					this.State_:SetState("SuccessEnd")
				end
			end

			--　購入完了シーケンス
			this.State_.func_["SuccessEnd"] = function()
				--Debug.PrintString("SuccessEnd")
				this.is_start = false
				this.mc_root.main:GotoAndPlay("bg_out")
				
				this.mc_root.main.window_1:GotoAndPlay("out")
				
				-- 買えたならネットワークエラーフラグは切る
				is_networkError = false

				-- C側に解放楽曲の情報を伝える
				if (is_joinPlayer[1] == true) then
					PlayDataManager.SetSongRelease(0, data.song_uniqueId, true)
				else
					PlayDataManager.SetSongRelease(1, data.song_uniqueId, true)					
				end
				
				-- 見かけ上の解放用にフラグを書き換える
				data.song_isOpen = true
				
				--　C++　側に通信終了を知らせる
				CppIsNetWorkStart = false
				
				--　シーケンスが終わったことをAllに伝える
				this:SetResultType(this.kResultDecided)
			end
			
			--　購入キャンセルシーケンス
			this.State_.func_["CancelEnd"] = function()
				--Debug.PrintString("CancelEnd")
				this.is_start = false
				this.mc_root.main:GotoAndPlay("bg_out")
				
				this.mc_root.main.window_1:GotoAndPlay("out")
				
				--　C++　側に通信終了を知らせる
				CppIsNetWorkStart = false	

				--　シーケンスが終わったことをAllに伝える
				this:SetResultType(this.kResultCanseled)
			end
			
			--　購入エラーシーケンス
			this.State_.func_["ErrorEnd"] = function()
				--Debug.PrintString("ErrorEnd")
				this.is_start = false
				this.mc_root.main:GotoAndPlay("bg_out")
				
				this.mc_root.main.window_1:GotoAndPlay("out")
				
				--　C++　側に通信終了を知らせる
				CppIsNetWorkStart = false
				
				--　シーケンスが終わったことをAllに伝える
				this:SetResultType(this.kResultCanseled)
			end

		end,
		
	-- ここまでInit
		
		-- トークンが足りなくて買えなかった時の表示時間
		waitNeedMoreTokenCnt = function(this)
			this.need_more_token_cnt = this.need_more_token_cnt + 1
			
			if (this.need_more_token_cnt >= this.wait_need_more_token_cnt) then
				this.need_more_token_cnt = 0
				return true
			else return false
			end
		end,

		-- お買い物ウィンドウを表示するまでの時間
		waitCnt = function(this)
			this.start_cnt = this.start_cnt + 1
			
			if (this.start_cnt >= this.wait_start_cnt) then
				this.start_cnt = 0
				return true
			else return false
			end
		end,

		-- サーバーとの通信中の表示時間
		waitNetworkCnt = function(this)
			this.network_cnt = this.network_cnt + 1
			
			if (this.network_cnt >= this.wait_network_cnt) then
				this.network_cnt = 0
				return true
			else return false
			end
		end,

		-- サーバーとの通信が成功した時の表示時間
		waitNetworkSuccessCnt = function(this)
			this.network_success_cnt = this.network_success_cnt + 1
			
			if (this.network_success_cnt >= this.wait_network_success_cnt) then
				this.network_success_cnt = 0
				return true
			else return false
			end
		end,

		-- サーバーとの通信が失敗した時の表示時間
		waitNetworkErrorCnt = function(this)
			this.network_error_cnt = this.network_error_cnt + 1
			
			if (this.network_error_cnt >= this.wait_network_error_cnt) then
				this.network_error_cnt = 0
				return true
			else return false
			end
		end,

		-- ごほうびの取得コンプリートしたときの表示時間
		waitRewardCompleteCnt = function(this)
			this.network_complete_cnt = this.network_complete_cnt + 1
			
			if (this.network_complete_cnt >= this.wait_network_complete_cnt) then
				this.network_complete_cnt = 0
				return true
			else return false
			end
		end,

		--　ステートの更新
		Update = function(this)
			-- ステート処理
			this.State_:Update()
			
		end,
	-- ここまでUpdate
		
		-- 再度シーケンスが戻った時用
		ReStartShop = function(this)
			this.State_:SetState("SetUp")
		end,
		
		--　カーソルの初期表示
		InitCursor = function(this)
			this.mc_root.main.window_1.panel.select_button:GotoAndStop("right")
		end,
		
		-- 左右入力
		MoveCursor = function(this, direction)
		
			this:PlaySeKatsu()
		
			this.selectIndex = this.selectIndex + direction
			
			if (this.selectIndex > this.kselectNot) then
				this.selectIndex = this.kselectNot
			
			elseif (this.selectIndex < this.kselectYes) then
				this.selectIndex = this.kselectYes
			end
			
			this:SelectBuyCursor()
			
		end,
		
		-- プレイヤー決定時
		DecidePlayer = function(this)
			
			local selectedIndex = 0
			
			if(this.selectIndex == 1) then
				-- ＳＥ「小どん（中央）」
				TSound:Play("se_common_v12a","don_c")
				selectedIndex = 1
			end
			
			if(this.selectIndex == 2) then
				-- ＳＥ「キャンセル」
				TSound:Play("se_common_v12a","primal_cancel_c")
				selectedIndex = 2
			end
			
			-- 1:買う
			-- 2:買わない
			return selectedIndex
		end,
		
		
		-- 1Pキー入力
		keyInput_1P = function (this)
			if (this:CheckInput() == this.INPUT_1P_DECIDE) then
				-- 選択時の処理
				-- ドンのSE
				this.decidedIndex = this:DecidePlayer()
				this.mc_root.main.window_1.panel.select_button.cursor:GotoAndPlay("decide")
				this.mc_root.main.window_1.panel.select_button.blink:GotoAndPlay("decide")

			elseif (this:CheckInput() == this.INPUT_1P_RIGHT) then
				-- 右ふち
				-- フォーカスを右へ移動
				this:MoveCursor(1)
			elseif (this:CheckInput() == this.INPUT_1P_LEFT) then
				-- 左ふち
				-- フォーカスを左へ移動
				this:MoveCursor(-1)
			end
		end,
		
		-- 2Pキー入力
		keyInput_2P = function (this)
			
			if (this:CheckInput() == this.INPUT_2P_DECIDE) then
				-- 選択時の処理
				this.decidedIndex = this:DecidePlayer()
				this.mc_root.main.window_1.panel.select_button.cursor:GotoAndPlay("decide")
				this.mc_root.main.window_1.panel.select_button.blink:GotoAndPlay("decide")
				
			elseif (this:CheckInput() == this.INPUT_2P_RIGHT) then
				-- 右ふち
				-- フォーカスを右へ移動
				this:MoveCursor(1)
				
			elseif (this:CheckInput() == this.INPUT_2P_LEFT) then
				-- 左ふち
				-- フォーカスを左へ移動
				this:MoveCursor(-1)
			end
		end,
		
		--　プレイヤーの入力受付を切る
		SetPlayerInputDisable = function(this)
			
			if (is_joinPlayer[1] == true) then					
				this:SetInputEnable_1p(false)
			elseif (is_joinPlayer[2] == true) then
				this:SetInputEnable_2p(false)
			end

		end,
		
		--　流し込み対応
		InitAllShopText = function(this)
		
			this.mc_root:SetText("main/window_1/panel/text_shop_info","text_shop_info","shop_info")
			this.mc_root:SetText("main/window_1/panel/select_button/text_cursor_left","text_cursor","shop_yes")
			this.mc_root:SetText("main/window_1/panel/select_button/text_cursor_right","text_cursor","shop_no")
			
			this.mc_root:SetText("main/window_1/panel/guide_instance/select_instance/text_guide_instance","text_guide","shop_select")
			this.mc_root:SetText("main/window_1/panel/guide_instance/decide_instance/text_guide_instance","text_guide","shop_decide")

		end,
		
		--　通信開始テキスト
		SetTextNetWorkConnect = function(this)
			this.mc_root:SetText("main/window_1/panel/text_shop_info","text_shop_info","shop_network_loading")
		end,
		
		--　通信成功テキスト
		SetTextNetWorkConnectSuccess = function(this)
			this.mc_root:SetText("main/window_1/panel/text_shop_info","text_shop_info","shop_network_success")
		end,
		
		--　通信失敗テキスト
		SetTextNetWorkConnectError = function(this)
			this.mc_root:SetText("main/window_1/panel/text_shop_info","text_shop_info","shop_network_error")
		end,

		--　全ごほうび獲得テキスト
		SetTextNetWorkConnectComplete = function(this)
			this.mc_root:SetText("main/window_1/panel/text_shop_info","text_shop_info","shop_complete")
		end,
		
		--　トークンが足りないテキスト
		SetTextNeedMoreToken = function(this)
			this.mc_root:SetText("main/window_1/panel/text_shop_info","text_shop_info","song_more_token")		
		end,
		
		-- 実行状態を取得する
		GetResult = function(this)
			return this.resultType
		end,
		
		-- 実行状態をセットする
		SetResultType = function(this, type)
			this.resultType = type
		end,
		
		-- ネットワークの状態を取得する
		GetNetWorkState = function(this)
			return this.networkState_
		end,
		
		-- プレイヤー1の入力受付可能かのフラグをゲットする
		GetInputEnable_1p = function(this)
			return this.is_inputEnable_1p
		end,

		-- プレイヤー1の入力受付可能かのフラグをセットする
		SetInputEnable_1p = function(this, setFlag)
			this.is_inputEnable_1p = setFlag
		end,
		
		-- プレイヤー1の入力受付可能かのフラグをセットする
		SetInputEnable_2p = function(this, setFlag)
			this.is_inputEnable_2p = setFlag
		end,

		-- プレイヤー2の入力受付可能かのフラグをゲットする
		GetInputEnable_2p = function(this)
			return this.is_inputEnable_2p
		end,
		
		-- どんSEをエントリーによって鳴らす
		PlaySeDon = function(this)
			TSound:Play("se_common_v12a","don_c")
		end,
		
		-- カツSEをエントリーによって鳴らす
		PlaySeKatsu = function(this)
			TSound:Play("se_common_v12a","katsu_c")
		end,

		-- ビープSEをエントリーによって鳴らす		
		PlaySeBeep = function(this)
			TSound:Play("se_common_v12a","beep_c")
		end,
		
		-- キャンセルSEをエントリーによって鳴らす		
		PlaySeCancel = function(this)
			TSound:Play("se_common_v12a","primal_cancel_c")
		end,
		
		-- ごほうびゲット時のVoice		
		PlayVoiceGet = function(this)
			TSound:Play("voice_common_v12a","get_c")
		end,
		
		-- 全ごほうびゲット時のVoice		
		PlayVoiceAllGet = function(this)
			TSound:Play("voice_common_v12a","gohoubi_complete_c")
		end,
		
		-- プレイヤーの入力状況をチェック
		CheckInput = function(this)
			
			if(is_joinPlayer[1] == true and this:GetInputEnable_1p() == true) then
				-- 1Pの入力
				if (Input.GetTrigger(Input.PLAYER1_OK) or Input.GetTrigger(Input.PLAYER1_CANCEL)) then return this.INPUT_1P_DECIDE end
				if (Input.GetTrigger(Input.PLAYER1_LEFT))	then return this.INPUT_1P_LEFT end
				if (Input.GetTrigger(Input.PLAYER1_RIGHT))	then return this.INPUT_1P_RIGHT end
			end
			
			if(is_joinPlayer[2] == true and this:GetInputEnable_2p() == true) then
				-- 2Pの入力
				if (Input.GetTrigger(Input.PLAYER2_OK) or Input.GetTrigger(Input.PLAYER2_CANCEL)) then return this.INPUT_2P_DECIDE end
				if (Input.GetTrigger(Input.PLAYER2_LEFT))	then return this.INPUT_2P_LEFT end
				if (Input.GetTrigger(Input.PLAYER2_RIGHT))	then return this.INPUT_2P_RIGHT end
			end	
		end,
		
		-- カーソル表示
		SelectBuyCursor = function(this)
			
			if(this.selectIndex == 1) then
				this.mc_root.main.window_1.panel.select_button:GotoAndStop("left")
			end
			
			if(this.selectIndex == 2) then
				this.mc_root.main.window_1.panel.select_button:GotoAndStop("right")
			end
		end,
		
		--　購入の可否決定時のアニメーションが終わったか
		IsEndSelectAnimation = function(this)
		
			if(this.mc_root.main.window_1.panel.select_button.blink:IsPlay() == false) then
				return true
			end
		end,
	
		--　タイムアップ時
		TimeUpSequence = function(this)	
			this.State_:SetState("CancelEnd")
		end,
		
	}
end