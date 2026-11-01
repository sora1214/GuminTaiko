-- 曲選択画面.ＱＲ関連Lua
-- Shusuke_Miura@al.bandainamco.jp

-- 使うクラスを読み込む
require("entry.qr_load")

--[[
※注意！！！！！）
ここはグローバルの
「songselectsong_」や「songselectui_」、引数で受け渡されてる「songselectmain」が
全く同じ形をしている前提で作っているので、元で初期化した時に足りない関数とかあると落ちます。
ほんとは呼び出し元は継承するとかして基本形を同じにしたいのですが、ちょっと修正範囲が膨大になるので、同名の関数追加とかでごまかしてます。
]]


-- このクラス
SongSelectQR = {
	fromStateName			 = "",						-- どこのシーケンスからきたのかを保存する
	is_touchFirstQRCode		 = false,					-- 一度でもQRコードをタッチしたか
	is_QRCodeTouching		 = false,					-- QRタッチシーケンス中か

	is_Trial = false,

	Init = function(this)
		-- ＱＲ読み込み
		QRLoad:Init()
	end,
	Setup = function(this)
		-- ＱＲ読み込み
		QRLoad:Setup()
	end,
	TouchWaitStart = function(this,scene)
		-- ＱＲ読み込み表示開始
		QRLoad:TouchWaitStart(true,scene)
	end,
	TouchWaitFinish = function(this)
		-- ＱＲ読み込み表示終了
		QRLoad:TouchWaitFinish()
	end,

	ChangeState = function(this,timer)
		if (is_touchQRCode == true and timer:IsZero() == false and songselectsong_:GetMoveFlag() == false and songselectsong_.is_setUpAllOk == true) then
			Debug.PrintString("[SongSelectQR] QRCode")

			this.is_touchFirstQRCode = true
			is_touchQRCode           = false

			-- 操作ガイドが大きい場合デフォルトに戻す
			if(songselectsong_:GetControlGuideFlag() == true) then
				songselectui_:StartDefaultControlGuide()
			end
			songselectsong_:SetControlGuideFlag(false)

			-- 入力を切る
			songselectsong_:SetInputEnable(false)

			-- QRコードシーケンスの準備
			songselectsong_:QRCodeSelectBegin(QRSelectSongUniqueId)
		end
	end,

	UpdateQR = function(this,songselectmain,state_)
		-- 楽曲お試し・獲得ＱＲの確認
		if(this.is_Trial == false) then
			this.is_Trial = true
			if(playSongCount < 2) then
				local musicId = QR.GetTrialSongUID()
				if(musicId > 0) then
					is_touchQRCode = true
					QRSelectSongUniqueId = musicId
					return
				end
			end
		end

		-- QRコードリーダの処理
		local qr_result = QRLoad:Update()
		-- 結果で分岐
		if(qr_result ~= 0) then

			-- QR以外のステートから来たのなら保存しておく
			if (state_ ~= "") then
				this.fromStateName = state_
			end

			-- QRタッチ中フラグを建てる
			this.is_QRCodeTouching = true

			-- 乱入できないようにフラグを設定する
			songselectsong_:Set2PEntryEnableFlag(false)

			-- タイマーカウントを停止
			songselectmain.timer_:StopCount()
			songselectmain.AllState_:SetState("QRState")
			-- 通信中などのウィンドウが出ているので、何かやってるのは止めた方がいい

			this.is_touchFirstQRCode = true
			if(songselectsong_:GetControlGuideFlag() == true) then
				songselectui_:StartDefaultControlGuide()
			end
			songselectsong_:SetControlGuideFlag(false)

			if(qr_result == 2) then
				-- 成功、カード読み込み領域のQR部分にデータが入っている。
				-- Debug.PrintString("success")
				QRLoad:TouchWaitStart(true,SceneType.kSongSelect)

				-- カード読み込み領域から選曲IDを取得
				local musicId = QR.GetSongSelectMusicIDFromTouchData()
				if(musicId > 0) then
					-- 曲指定に行く
					Debug.PrintString("song jump")

					-- タッチした情報をプレイヤー情報に入れる→後で「QR使用」が実行される
					QR.UpdateUserQRFromTouchData(0)
					QR.UpdateUserQRFromTouchData(1)

					-- QR読み込み停止（QR後のアニメーションが終わるまでQR読み込み停止）
--					QRLoad:TouchWaitFinish()

					is_touchQRCode = true
					QRSelectSongUniqueId = musicId
				end

				-- タイマーカウントを再開
				songselectmain.timer_:StartCount()
				-- 乱入可能フラグを建てる
				songselectmain:Set2PEntryEnable()
				-- 終わったら戻す
				this.is_QRCodeTouching = false

				-- 入ってきたシーケンスに戻す
				songselectmain.AllState_:SetState(this.fromStateName)
			elseif(qr_result == -1) then
				-- エラー 何もしない
				Debug.PrintString("QR ERROR")
				QRLoad:TouchWaitStart(true,SceneType.kSongSelect)
				
				-- タイマーカウントを再開
				songselectmain.timer_:StartCount()
				-- 乱入可能フラグを建てる
				songselectmain:Set2PEntryEnable()
				-- 終わったら戻す
				this.is_QRCodeTouching = false

				-- 入ってきたシーケンスに戻す
				songselectmain.AllState_:SetState(this.fromStateName)
				return
			else
				return
			end
		end
	end,
}
