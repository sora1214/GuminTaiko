-- Caution.lua
-- バチ注意喚起画面

-- 対応するlumenファイル
UseLumenFile = "lumen/000_default/attract/caution"

-- 使うクラスを読み込む
require("common.Sound")
require("common.State")

-- 初期化処理
function Init()
	-- シーケンス
	CautionScene = State.New("Caution")

	-- ステートマシン構築
	CautionScene.func_["Begin"] = function()
		-- ムービークリップ
		CautionScene.main_mc_ = Lumen.GetMovieClip("caution_instance_0",true)
		-- １フレーム目から再生
		CautionScene.main_mc_:GotoAndPlay(1)

		-- 変数
		CautionScene.now_time_ = 0
		CautionScene.total_time_ = 7 * Common.FPS

		-- ここからカードタッチ有効
		local card_status = BanaPass.GetCardTouchStatus()
		if((card_status == GameConnectStatus.kSuccess) or (card_status == GameConnectStatus.kError)) then
		else
			BanaPass.StartCardTouch()
		end
		-- ここからＱＲタッチ有効
		local qr_status = QR.GetQRTouchStatus()
		if((qr_status == GameConnectStatus.kSuccess) or (qr_status == GameConnectStatus.kError)) then
		else
			QR.StartQRTouch()
		end

		CautionScene:SetState("Main")
	end

	CautionScene.func_["Main"] = function()
		-- カウント
		CautionScene.now_time_ = CautionScene.now_time_ + 1

		-- メニューテスト以外
		if(IsFromMenuTest == false) then
			-- 時間制御する
			if(CautionScene.now_time_ > CautionScene.total_time_) then
				CautionScene:SetState("EndWait")
			end
		end

		-- サウンド制御
		if(CautionScene.main_mc_.current_frame == 32) then
			-- ボイスＳＥ「危険なので、バチをふりまわしたり太鼓以外のものを叩いたりしないでね」
			TSound:Play("voice_common_v12a","caution")
			-- ＳＥ「ヒュン、ヒュン…」
--			TSound:Play("se_common_v12a","caution_swing")
		end
		if(CautionScene.main_mc_.current_frame == 140) then
			-- ＳＥ「ビシ」
--			TSound:Play("se_common_v12a","caution_hit")
		end
		if(CautionScene.main_mc_.current_frame == 228) then
			-- ＳＥ「ブブー」
--			TSound:Play("se_common_v12a","caution_buzzer")
		end

--		if(CautionScene.main_mc_:IsInCurrentLabelMc("","voice") == true) then
	end

	CautionScene.func_["EndWait"] = function()
		-- シーン終了
		Common.LuaFinish()
		CautionScene:SetState("End")
	end
	CautionScene.func_["End"] = function()
	end

end

-- 毎フレームの処理
function Proc()
	CautionScene:Update()
end


