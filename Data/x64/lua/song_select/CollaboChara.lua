-- コラボキャラ表示制御用
CollaboChara = {}
function CollaboChara.New(name, idx)
	return
	{	
		name_ = name,
		mc_,			-- このMC
		main_,			-- mainMC
		idx_ = idx,
		existing_ = false, 
		charaName = "",

		CollaboCharaLoadMovie = function(this)
			Debug.PrintString("CollaboChara LoadMovie enter")

			-- ToDo: QRコラボの状況をみてloadMovie
			local collaboCharaFla = ""
			local play_data = PlayDataManager.GetEntryPlayData(this.idx_-1)
			if(play_data.qr_data.qrDataList_size > 0) then
				Debug.PrintString("before Collabo load" .. this.idx_)
				local qrCodeInfo = QRCodeInfo.create(play_data.qr_data.qrDataList[1].responseId) -- 1でいいかは後で確認
				if(qrCodeInfo.costumeType == QRCostumeType.kFlaChara) then
					this.charaName = qrCodeInfo.id
					collaboCharaFla = "lumen/"..qrCodeInfo.taikoselect_fla
				end
			end

			Debug.PrintString("CollaboChara LoadMovie " .. collaboCharaFla)
			if(collaboCharaFla == "") then
				this.existing_ = false
			else
				Lumen.LoadMovie(collaboCharaFla, this.name_)
				this.existing_ = true
			end
		end,

		-- リザルト時のコラボキャラ表示設定
		CollaboCharaLoadMovieResult = function(this, uniqueId)
			Debug.PrintString("CollaboChara LoadMovie Result enter")
			
			local collaboCharaFla = ""
			if(uniqueId == "")then
				-- コラボキャラ無し
			else
				-- あり
				collaboCharaFla = "lumen/"..uniqueId
			end

			if(collaboCharaFla == "") then
				this.existing_ = false
			else
				Lumen.LoadMovie(collaboCharaFla, this.name_)
				this.existing_ = true
			end
		end,
		
		-- 初期化
		CollaboCharaSetup = function(this)
			Debug.PrintString("CollaboChara Setup ")
			if (Lumen.IsLoadMovieFinish() == true) then
				-- ムービークリップ取得
				this.mc_ = Lumen.GetMovieClip(this.name_,true)
				if(this.existing_ == false) then 
					this.mc_:SetVisible(false)
				else
					this.mc_:SetVisible(true)
					this.main_ = this.mc_.main_instance
				end

				this:CollaboCharaSetSide(this.idx_)
			end
		end,
	
		-- プレイヤー情報設定
		CollaboCharaSetSide = function(this, side)
			if(this.existing_ == false) then return end
			Debug.PrintString("CollaboChara SetSide")

			if(side == 1) then
				this.main_:GotoAndStop("1p")
			else
				this.main_:GotoAndStop("2p")
			end
		end,

		-- 描画開始
		CollaboCharaFadeIn = function(this)
			if(this.existing_ == false) then return end

			Debug.PrintString("CollaboChara FadeIn")
			this.mc_:GotoAndPlay("in")
			this:CollaboCharaToWaitMotion()
		end,

		-- 描画（フェードイン無し）
		CollaboCharaDisplay = function(this)
			if(this.existing_ == false) then return end

			Debug.PrintString("CollaboChara FadeIn")
			this.mc_:GotoAndPlay("keep")
			this:CollaboCharaToWaitMotion()
		end,

		-- 各種モーションに移行
		CollaboCharaSetMotion = function(this, label)
			if(this.existing_ == false) then return end
			if(this.idx_ == 1) then
				this.main_.contents_1p_instance:GotoAndPlay(label)
			else
				this.main_.contents_2p_instance:GotoAndPlay(label)
			end
		end,

		-- 待機モーションに移行
		CollaboCharaToWaitMotion = function(this)
			this:CollaboCharaSetMotion("wait")
		end,

		-- 決定モーションに移行
		CollaboCharaToDecideMotion = function(this)
			this:CollaboCharaSetMotion("decide")
		end,


		-- リザルト用台詞のpostfixを返す
		GetCollaboCharaId = function(this)
			--Debug.PrintString("GetCollaboCharaId ")
			--Debug.PrintString(this.charaName)
			return this.charaName
		end,
	}
end

