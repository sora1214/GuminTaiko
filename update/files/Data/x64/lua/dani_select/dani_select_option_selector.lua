-- 段位選択画面.段位選択オプション 選択用クラスLua
-- Masayuki_Teraoka@al.bandainamco.jp

-- 使うクラスを読み込む
require("common.Sound")

DaniSelectOptionSelector = {}
function DaniSelectOptionSelector.New(InstanceName_1)
	return
	{
		mc_selector_ = InstanceName_1,
		mc_selectArrow_l_	= {},		-- 選択項目の左矢印
		mc_selectArrow_r_	= {},		-- 選択項目の右矢印

		mc_onpuPosition_ = {},			-- 音符調整ウィンドウ
		mc_onpuPositionSelect_ = {},	-- 音符調整選択ウィンドウ

		mc_EnsoSkip_ = {},				-- 演奏スキップ用ウィンドウ

		optionItemName	= "",

		tbl_ItemLabel = {},				-- 自分の選択肢
		
		itemNumLength		= 0,
		current				= 1,
		sessionIndex		= 0,
		onpuSelectParam		= 0,		-- 音符位置調整値
		frameCounter = 0,				-- Update開始から60フレーム待機するため

		isOpenOnpuPosition = false,		-- 音符位置調整が開かれているか否か
		isCautionOptionFlag = false,	-- 記録不可オプションが有効かどうか
		isWaitNeiro = false,
		neiroPlayCurrent	= 0,		-- 現在再生している音色
		neiroSlot = 0,					-- 音色で設定しているスロット
		neiroTimer = 0,					-- 音色再生フレーム
		neiroStartWait = 0,				-- スタートの待ち時間

		AllNeiro_ = {},

		LEFT_	= 1,					-- プレイヤー/左カツ
		RIGHT_	= 2,					-- プレイヤー/右カツ

		kPlayer1 = 1,					-- 1P
		kPlayer2 = 2,					-- 2P
		
		Init = function(this, sessionIndex_, label_)

			this.sessionIndex = sessionIndex_
			this.tbl_ItemLabel = label_

			this.itemNumLength = #label_
			this.mc_selector_:GotoAndStop("select_cursor", "off")

			this:InitOptionName(sessionIndex_)
			this:InitOptionItemName(sessionIndex_)
			this:InitMc()

			this.isOpenOnpuPosition = false
		end,
				
		InitOptionName = function(this, sessionIndex_)
			if (sessionIndex_ == 1) then
				this.mc_selector_:SetText("text_option_name","text_option_name","option_speed")
			elseif (sessionIndex_ == 2) then
				this.mc_selector_:SetText("text_option_name","text_option_name","option_doron")
			elseif (sessionIndex_ == 3) then
				this.mc_selector_:SetText("text_option_name","text_option_name","option_abekobe")
			elseif (sessionIndex_ == 4) then
				this.mc_selector_:SetText("text_option_name","text_option_name","option_random")
			elseif (sessionIndex_ == 5) then
				this.mc_selector_:SetText("text_option_name","text_option_name","option_skip")
			elseif (sessionIndex_ == 6) then
				this.mc_selector_:SetText("text_option_name","text_option_name","option_position")
			elseif (sessionIndex_ == 7) then
				this.mc_selector_:SetText("text_option_name","text_option_name","option_voice")
			elseif (sessionIndex_ == 8) then
				this.mc_selector_:SetText("text_option_name","text_option_name","option_neiro")
			end

		end,
		
		InitOptionItemName = function(this, sessionIndex_)
		
			if (sessionIndex_ == 1) then		-- はやさ
				this.mc_selector_:SetText("text_item_name","text_item_name","1.0")
				this.optionItemName = "1.0"
			elseif (sessionIndex_ == 2) then	-- ドロン
				this.mc_selector_:SetText("text_item_name","text_item_name","option_off")
				this.optionItemName = "option_off"
			elseif (sessionIndex_ == 3) then	-- あべこべ
				this.mc_selector_:SetText("text_item_name","text_item_name","option_off")
				this.optionItemName = "option_off"
			elseif (sessionIndex_ == 4) then	-- ランダム
				this.mc_selector_:SetText("text_item_name","text_item_name","option_off")
				this.optionItemName = "option_no"
			elseif (sessionIndex_ == 5) then	-- 演奏スキップ
				this.mc_selector_:SetText("text_item_name","text_item_name","option_off")
				this.optionItemName = "option_off"
			elseif (sessionIndex_ == 6) then	-- 音符位置調整
				this.mc_selector_:SetText("text_item_name","text_item_name","option_off")
				this.optionItemName = "option_off"
			elseif (sessionIndex_ == 7) then	-- ボイス
				this.mc_selector_:SetText("text_item_name","text_item_name","option_no")
				this.optionItemName = "option_no"
			elseif (sessionIndex_ == 8) then	-- 音色
				this.mc_selector_:SetText("text_item_name","text_item_name","neiro_taiko")
				this.optionItemName = "neiro_taiko"
			end
			
		end,

		InitMc = function(this)
			this.mc_selectArrow_l_:GotoAndStop("off")
			this.mc_selectArrow_r_:GotoAndStop("off")
		end,
		
		-- カーソルを左に変更時
		Tween_Left = function(this, sessionIndex_)

			-- 音符位置調整ウィンドウが開いている場合
			if(this.isOpenOnpuPosition == false)then
				this.current =  this.current - 1
				if ( this.current < 1 ) then this.current = this.itemNumLength end
			end

			this.mc_selectArrow_l_:GotoAndPlay("select")

			-- テキストの設定
			this:TextSet(sessionIndex_, true, this.LEFT_)

			if(this.current == 1)then
				this.mc_selector_:GotoAndStop("option_select_change_mc", "default")
			else
				this.mc_selector_:GotoAndStop("option_select_change_mc", "change")
			end
			
			this:SelectCautionIcon(sessionIndex_, this.current)
			
		end,

		-- カーソルを右に変更時
		Tween_Right = function(this, sessionIndex_)

			-- 音符位置調整ウィンドウが開いている場合
			if(this.isOpenOnpuPosition == false)then
				this.current =  this.current + 1
				if ( this.current > this.itemNumLength ) then this.current = 1 end
			end

			this.mc_selectArrow_r_:GotoAndPlay("select")

			-- テキストの設定
			this:TextSet(sessionIndex_, true, this.RIGHT_)


			if(this.current == 1)then
				this.mc_selector_:GotoAndStop("option_select_change_mc", "default")
			else
				this.mc_selector_:GotoAndStop("option_select_change_mc", "change")
			end
			
			this:SelectCautionIcon(sessionIndex_, this.current)
			
		end,

		-- テキストの設定
		-- isSelect:オプション選択中に入った場合trueに設定。その他初期化等で使用する場合、falseに設定
		TextSet = function(this, sessionIndex_, isSelect, direction)
			Debug.PrintString("sessionIndex_")
			Debug.PrintString(sessionIndex_)
			
			if(this.current == 1)then
				this.mc_selector_:GotoAndStop("option_select_change_mc", "default")
			else
				this.mc_selector_:GotoAndStop("option_select_change_mc", "change")
			end

			if (sessionIndex_ == 1) then
				-- はやさ
				this:SetOptionItem_Speed(this.current)
			elseif (sessionIndex_ == 2) then
				-- ドロン
				this:SetOptionItem_OnOff(this.current)
			elseif (sessionIndex_ == 3) then
				-- あべこべ
				this:SetOptionItem_OnOff(this.current)
			elseif (sessionIndex_ == 4) then
				-- ランダム
				this:SetOptionItem_Random(this.current)
			elseif (sessionIndex_ == 5) then
				-- 演奏スキップ
				this:SetOptionItem_OnOff(this.current)
				
				-- 選択中の場合、ウィンドウを開く
				if(isSelect == true)then this:EnsoSkipSelect(this.current)end

			elseif (sessionIndex_ == 6) then
				-- 音符位置調整
				this:OnpuPositionSelect(direction, isSelect)
			elseif (sessionIndex_ == 7) then
				-- ボイス
				this:SetOptionItem_YesNo(this.current)
			elseif (sessionIndex_ == 8) then
				-- 音色
				this:SetOptionItem_Neiro(this.current)
			end
		end,

		-- 待ち
		Wait = function(this)
			if (this.sessionIndex == 1) then
				-- はやさ
				if(this.frameCounter < Common.FPS * 1)then
					this.frameCounter = this.frameCounter + 1
					return true
				end
			elseif (this.sessionIndex == 2) then
				-- ドロン
			elseif (this.sessionIndex == 3) then
				-- あべこべ
			elseif (this.sessionIndex == 4) then
				-- ランダム
			elseif (this.sessionIndex == 5) then
				-- 演奏スキップ
			elseif (this.sessionIndex == 6) then
				-- 音符位置調整
			elseif (this.sessionIndex == 7) then
				-- ボイス
			elseif (this.sessionIndex == 8) then
				-- 音色
			end

			-- 何も待ちがない場合
			return false
		end,

		-- カーソル更新の処理
		UpdateCursor = function(this)
			if (this.sessionIndex == 1) then
				-- はやさ
			elseif (this.sessionIndex == 2) then
				-- ドロン
			elseif (this.sessionIndex == 3) then
				-- あべこべ
			elseif (this.sessionIndex == 4) then
				-- ランダム
			elseif (this.sessionIndex == 5) then
				-- 演奏スキップ
			elseif (this.sessionIndex == 6) then
				-- 音符位置調整
			elseif (this.sessionIndex == 7) then
				-- ボイス
			elseif (this.sessionIndex == 8) then
				-- 音色
				this:NeiroUpdate()
			end
		end,

		-- カーソル開始時の処理
		StartCursor = function(this)
			if (this.sessionIndex == 1) then
				-- はやさ
				this.frameCounter = 0
			elseif (this.sessionIndex == 2) then
				-- ドロン
			elseif (this.sessionIndex == 3) then
				-- あべこべ
			elseif (this.sessionIndex == 4) then
				-- ランダム
			elseif (this.sessionIndex == 5) then
				-- 演奏スキップ
				this:StartEnsoSkip()
			elseif (this.sessionIndex == 6) then
				-- 音符位置調整
				this:StartOnpuPosition()
			elseif (this.sessionIndex == 7) then
				-- ボイス
			elseif (this.sessionIndex == 8) then
				-- 音色
				this:StartNeiro()
			end
		end,

		-- カーソル終了時の処理
		EndCursor = function(this)
			if (this.sessionIndex == 1) then
				-- はやさ
			elseif (this.sessionIndex == 2) then
				-- ドロン
			elseif (this.sessionIndex == 3) then
				-- あべこべ
			elseif (this.sessionIndex == 4) then
				-- ランダム
			elseif (this.sessionIndex == 5) then
				-- 演奏スキップ
				this:EndEnsoSkip()
			elseif (this.sessionIndex == 6) then
				-- 音符位置調整
				this:EndOnpuPosition()
			elseif (this.sessionIndex == 7) then
				-- ボイス
			elseif (this.sessionIndex == 8) then
				-- 音色
				this:EndNeiro()
			end
		end,
		
		-- 記録残らないアイコンの切り替え
		SelectCautionIcon = function(this, sessionIndex, current)
		
			if (sessionIndex ~= 5 and sessionIndex ~= 6 and sessionIndex ~= 7) then
				if (current ~= 1) then
					this.isCautionOptionFlag = true
					this.mc_selector_.caution_icon:GotoAndStop("on")
				else
					this.isCautionOptionFlag = false
					this.mc_selector_.caution_icon:GotoAndStop("off")
				end
			end
		end,
		
		-- カーソルの表示on/off
		SetSelectCursor = function(this, flag)
			if(flag) then
				this.mc_selector_:GotoAndStop("select_cursor", "on")
				this.mc_selectArrow_l_:GotoAndStop("on")
				this.mc_selectArrow_r_:GotoAndStop("on")
			else
				this.mc_selector_:GotoAndStop("select_cursor", "off")
				this.mc_selectArrow_l_:GotoAndStop("off")
				this.mc_selectArrow_r_:GotoAndStop("off")
			end
		end,

		-- 設定項目(文字列)を取得
		GetOptionItemName = function(this)
			return this.optionItemName
		end,

		-- 設定項目(数値)を取得
		GetOptionCurrent = function(this)
			if(this.sessionIndex == 6)then
			--#01
				if(this.current == 1)then
					-- 設定なし
					return 0
				else
					-- 設定あり
					return this.onpuSelectParam
				end
			else
				return this.current - 1
			end
		end,

		-- 設定項目の変更(option_on/option_off ) 
		SetOptionItem_OnOff =function(this, number)
			-- (option_on/option_off) = (する / しない)
			Debug.PrintString("オプションon/off")
			Debug.PrintString("number = "..number)
			if(number == 1)then
				this.mc_selector_:SetText("text_item_name","text_item_name","option_off")
				this.optionItemName = "option_off"
			elseif(number == 2)then
				this.mc_selector_:SetText("text_item_name","text_item_name","option_on")
				this.optionItemName = "option_on"
			end
		end,

		-- 設定項目の変更(option_yes/option_no)
		SetOptionItem_YesNo =function(this, number)
			-- (option_yes/option_no) = (あり / なし)
			Debug.PrintString("オプションyes/no")
			Debug.PrintString("number = "..number)
			if(number == 1)then
				this.mc_selector_:SetText("text_item_name","text_item_name","option_yes")
				this.optionItemName = "option_yes"
			elseif(number == 2)then
				this.mc_selector_:SetText("text_item_name","text_item_name","option_no")
				this.optionItemName = "option_no"
			end
		end,

		-- "ランダム"項目の変更(option_no / option_kimagure / option_detarame)
		SetOptionItem_Random =function(this, number)
			-- (option_no / option_kimagure / option_detarame)
			Debug.PrintString("オプション no/kimagure/detarame")
			Debug.PrintString("number = "..number)
			if(number == 1)then
				this.mc_selector_:SetText("text_item_name","text_item_name","option_no")
				this.optionItemName = "option_no"
			elseif(number == 2)then
				this.mc_selector_:SetText("text_item_name","text_item_name","option_kimagure")
				this.optionItemName = "option_kimagure"
			elseif(number == 3)then
				this.mc_selector_:SetText("text_item_name","text_item_name","option_detarame")
				this.optionItemName = "option_detarame"
			end
		end,

		-- "はやさ"項目の変更
		SetOptionItem_Speed =function(this, number)
			Debug.PrintString("number = "..number)
			this.mc_selector_:SetText("text_item_name","text_item_name","option_speed_0"..string.format("%02d",number))
			this.optionItemName = "option_speed_0"..string.format("%02d",number)
		end,

		-- "音色"項目の変更
		SetOptionItem_Neiro =function(this, number)
			Debug.PrintString("label = "..this.tbl_ItemLabel[number])
			this.mc_selector_:SetText("text_item_name","text_item_name",this.tbl_ItemLabel[number])
			this.optionItemName = this.tbl_ItemLabel[number]
		end,

		-- 演奏スキップ
		EnsoSkipSelect = function(this, number)
			if(number == 1)then
				-- ウィンドウを閉じる
				this.mc_EnsoSkip_:GotoAndPlay("skip_off")
			elseif(number == 2)then
				-- ウィンドウを開く
				this.mc_EnsoSkip_:SetVisible(true)
				this.mc_EnsoSkip_:GotoAndPlay("skip_on")
			end
		end,

		-- 音符位置調整
		-- isSelect:オプション選択中に入った場合trueに設定。その他初期化等で使用する場合はfalseに設定
		OnpuPositionSelect = function(this, input, isSelect)

			if(isSelect)then
				if(this.isOpenOnpuPosition == true)then
					-- 音符位置調整ウィンドウが開かれているとき
					Debug.PrintString("onpuSelectParam = "..this.onpuSelectParam)
					-- 音符の位置を調整
					if(input == this.LEFT_) then
						-- 左
						this.onpuSelectParam = this.onpuSelectParam - 1
						if(this.onpuSelectParam < -5)then this.onpuSelectParam = -5 end
						this:SetOnpuPositionGotoPlay(this.onpuSelectParam)
						this.mc_onpuPosition_:GotoAndPlay("option_select_arrow_left","select")
						
					end
	
					if(input == this.RIGHT_) then
						-- 右
						this.onpuSelectParam = this.onpuSelectParam + 1
						if(this.onpuSelectParam > 5)then this.onpuSelectParam = 5 end
						this:SetOnpuPositionGotoPlay(this.onpuSelectParam)
						this.mc_onpuPosition_:GotoAndPlay("option_select_arrow_right","select")
					end
				else
					-- 音符位置調整ウィンドウが開かれていないとき
					this:SetOptionItem_OnOff(this.current)
					if(this.current == 0)then
						this.onpuSelectParam = 0
					end
					if(input == this.LEFT_) then this.mc_selectArrow_l_:GotoAndPlay("select") end
					if(input == this.RIGHT_) then this.mc_selectArrow_r_:GotoAndPlay("select") end
				end
			else
				-- 選択中ではない場合、設定のみ行う
				this.onpuSelectParam = this.onpuSelectParam
				this:SetOnpuPositionGotoPlay(this.onpuSelectParam)
				if(this.current == 1)then
					this.mc_selector_:SetText("text_item_name","text_item_name","option_off")
					this.optionItemName = "option_off"
					this.onpuSelectParam = 0
				else
					this.mc_selector_:SetText("text_item_name","text_item_name","option_on")
					this.optionItemName = "option_on"
				end
			end
			-- this.mc_selector_:SetText("text_item_name","text_item_name",this.tbl_ItemLabel[this.current])
			--this.optionItemName = "option_no"
			
		end,

		-- 音符位置の調整
		SetOnpuPositionGotoPlay = function(this, position)
			Debug.PrintString("position = "..position)
			if(position == 0)then
				-- 0
				this.mc_onpuPositionSelect_:GotoAndStop("0")
				this.mc_onpuPosition_:SetText("text_onp_position","text_position","option_position_006")
				
			elseif(position < 0)then
				-- -1～-5
				this.mc_onpuPositionSelect_:GotoAndStop("left"..(position*-1))
				this.mc_onpuPosition_:SetText("text_onp_position","text_position","option_position_00"..6 - (position*-1))
			elseif(position > 0)then
				--  1～5
				this.mc_onpuPositionSelect_:GotoAndStop("right"..position)
				this.mc_onpuPosition_:SetText("text_onp_position","text_position","option_position_0"..string.format("%02d",6 + position))
			end
		end,

		-- 音符位置調整ウィンドウのフラグを設定
		SetIsOnpuPosition = function(this, flag)
			this.isOpenOnpuPosition = flag
		end,

		-- 音符位置調整が開かれているか否か
		GetIsOnpuPosition = function(this)
			return this.isOpenOnpuPosition
		end,

		-- 音符位置調整ウィンドウを開く
		OpenOnpuPosition = function(this)
			this.mc_onpuPosition_:GotoAndPlay("open")
			-- フラッシュ修正終わったら上記で実装、完成するまで仮で下記使用
			-- this:SetOnpuPositionGotoPlay(this.onpuSelectParam)
			this.isOpenOnpuPosition = true
		end,

		-- 音符位置調整ウィンドウを閉じる
		CloseOnpuPosition = function(this)
			this.mc_onpuPosition_:GotoAndPlay("close")

			this.isOpenOnpuPosition = false
		end,

		-- 音符位置調整のmcを設定
		SetOnpuPositionMc = function(this, mc, mc2)
			this.mc_onpuPosition_ = mc
			this.mc_onpuPosition_:SetText("close_text","close_text","option_position_window")
			this.mc_onpuPositionSelect_ = mc2
		end,

		-- 演奏スキップテキストのmcを設定
		SetEnsoSkipMc = function(this,mc)
			this.mc_EnsoSkip_ = mc
			this.mc_EnsoSkip_:SetText("enso_skip_text","enso_skip_text","option_enso_skip_window")
		end,

		-- 演奏スキップの開始時の処理
		StartEnsoSkip = function(this)
			-- 表示

			this.mc_EnsoSkip_:SetVisible(true)
			if(this.current == 1)then
				this.mc_EnsoSkip_:GotoAndStop("skip_on")
			else
				this.mc_EnsoSkip_:GotoAndPlay("skip_on")
			end
		end,

		-- 演奏スキップの終了時の処理
		EndEnsoSkip = function(this)
			if(this.current == 1)then
				this.mc_EnsoSkip_:GotoAndStop("skip_on")
			else
				this.mc_EnsoSkip_:GotoAndPlay("skip_off")
			end
		end,

		-- 音符位置調整の開始時の処理
		StartOnpuPosition = function(this)
			this.mc_onpuPosition_:SetVisible(true)
			this.mc_onpuPosition_:GotoAndPlay("on")
		end,

		-- 音符位置調整の終了時の処理
		EndOnpuPosition = function(this)
			this.mc_onpuPosition_:GotoAndStop("on")
			-- this.current = this.onpuSelectParam
		end,

		-- 矢印のmcを設定
		SetSelectArrowMc = function(this, mc1, mc2)
			this.mc_selectArrow_l_ = mc1
			this.mc_selectArrow_r_ = mc2
		end,

		-- グレーアウト設定
		GrayOut = function(this)
			this.mc_selector_:GotoAndStop("grayout")
		end,

		-- 音色選択時の初期化
		StartNeiro = function(this)
			-- 処理
			Debug.PrintString("音色の初期化")

			this.isWaitNeiro = false
			this.neiroPlayCurrent = 0
			this.neiroTimer = 0
			this.neiroStartWait = 0

			num = 0
			for idx = 0, this.itemNumLength-1 do
				num = this:GetHasToNeiro(idx+1)
				Debug.PrintString("LoadBank = ".."se_neiro_"..string.format("%02d",num-1).."_v12a")
				TSound:LoadBank("se_neiro_"..string.format("%02d",num-1).."_v12a")
				--TSound:LoadBank("se_neiro_"..string.format("%02d",idx).."_v12a")
			end
		end,

		-- 音色選択時の更新
		NeiroUpdate = function(this)
			-- 処理
			if(this.neiroStartWait > (0.2 * Common.FPS))then
				this.neiroTimer = this.neiroTimer + 1

				--if(TSound:IsPlayingSlot(this.neiroSlot) == false and this.isWaitNeiro == false)then
				if(this.neiroTimer > (0.5 * Common.FPS))then
					-- 次の音色を再生

					num = this:GetHasToNeiro(this.current)
					if(this.neiroPlayCurrent == 0)then
						TSound:PlaySlot("se_neiro_"..string.format("%02d",(num-1)).."_v12a","don_c",this.neiroSlot)
						--TSound:PlaySlot("se_neiro_"..string.format("%02d",(this.current-1)).."_v12a","don_c",this.neiroSlot)
						this.neiroPlayCurrent = 1
					else
						TSound:PlaySlot("se_neiro_"..string.format("%02d",(num-1)).."_v12a","katsu_c",this.neiroSlot)
						this.neiroPlayCurrent = 0
					end
					this.neiroTimer = 0
					--this.isWaitNeiro = true
				else
					-- 再生中
					--if(TSound:IsPlayingSlot(this.neiroSlot) == true and this.isWaitNeiro == true)then
					--	this.isWaitNeiro = false
					--end
				end
			else
				this.neiroStartWait = this.neiroStartWait + 1
				if(this.neiroStartWait > 0.2 * Common.FPS)then
					this.neiroPlayCurrent = 1
					num = this:GetHasToNeiro(this.current)
					TSound:PlaySlot("se_neiro_"..string.format("%02d",(num-1)).."_v12a","don_c",this.neiroSlot)
				end
			end
		end,

		-- 音色選択時の終了処理
		EndNeiro = function(this)
			-- 処理
			Debug.PrintString("音色終了")
--			Debug.PrintString("音色の初期化")
--			for idx = 0, this.itemNumLength-1 do
--				--TSound:UnloadBank("se_neiro_"..string.format("%02d",idx).."_v12a")
--			end
		end,

		-- 音色を再生するスロットを設定
		SetNeiroSlot =function(this, num)
			this.neiroSlot = num
		end,

		-- 音色
		SetNeiroAll = function(this, neiro)
			this.AllNeiro_ = neiro
		end,

		GetHasToNeiro = function(this, idx)
			local num = 1

			for i = 1, #this.AllNeiro_ do
				if(this.tbl_ItemLabel[idx] == this.AllNeiro_[i])then
					num = i
				end
			end
			return num
		end,

		-- オプションの値を設定
		-- サーバーの値は0から始まるので、+1する
		SetOptionParam = function(this, num)
			-- 文字列を設定
			if (this.sessionIndex == 6) then
				-- 音符調整の場合
				if(num == 0)then
					this.optionItemName = this.tbl_ItemLabel[1]
					this.current = 1
				else
					this.optionItemName = this.tbl_ItemLabel[2]
					this.current = 2
				end

				this.onpuSelectParam = num
			else
				this.optionItemName = this.tbl_ItemLabel[num + 1]
				this.current = num + 1
			end
		end,

		-- 音符位置の値をサーバへ渡す用の数値に変換する。
		PositionToParam = function(this, num)
			if(num == 0)then	-- 0の場合
				return 1
			elseif(this.current == 1)then
				-- 設定しない、の場合
				return 1
			elseif(num >= -5 and num <= -1)then	-- 位置が左調整の場合
				return num+7
			elseif(num >= 1 and num <= 5)then	-- 位置が右調整の場合
				return num+6
			end
		end,

		-- サーバから受け取った値を音符位置用の数値に変換する。
		ParamToPosition = function(this, num)
			if(num == 1)then	-- 0の場合
				return 0
			elseif(num >= 2 and num <= 6)then	-- 位置が左調整の場合
				return (7-num)*-1
			elseif(num >= 7 and num <= 11)then	-- 位置が右調整の場合
				return (num-6)
			end
		end,

	}
end

