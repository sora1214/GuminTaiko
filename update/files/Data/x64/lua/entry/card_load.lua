-- �o�i�p�X��t
require("common.State")
require("common.Sound")

CardLoad = {
	Init = function(this)
		this.state_ = State.New("CardLoad")
		this.result_ = 0
		this.result_reserve_ = 0
		this.error_code_ = CardTouchError.kNone
	end,
	-- ������
	Setup = function(this)
		-- �X�e�[�g�}�V���g�ݗ��Ă�
		this.state_.func_["Begin"] = function()
			-- �����ŊJ�n���Ȃ�
		end
		this.state_.func_["CardTouchWait"] = function()
			local card_status = BanaPass.GetCardTouchStatus()
			if((card_status ~= GameConnectStatus.kNone) and (card_status ~= GameConnectStatus.kWait)) then
				-- �ǂݍ��ݒ��\���ɂ���
				NetAccessWindow.StartLoading("now_connectserver")

				-- �r�d����
				TSound:StopSlot(kEntrySoundSlot_CautionVoice0)

				-- �r�d�u�o�i�p�X�|�[�g�ǂݍ��ݒ��v
--				TSound:PlaySlot("se_common_v12a","card_reading_loop",kEntrySoundSlot_CautionVoice1)

				-- ��������
				this.result_ = 1

				this.state_:SetState("ToReading")
			end
		end
		this.state_.func_["ToReading"] = function()
			if(NetAccessWindow.IsPlay() == false) then
				this.state_:SetState("CardReading")
			end
		end
		this.state_.func_["CardReading"] = function()
			local card_status = BanaPass.GetCardTouchStatus()
			if((card_status == GameConnectStatus.kSuccess) or (card_status == GameConnectStatus.kError)) then
				if(card_status == GameConnectStatus.kSuccess) then
					-- �G���g���[�ς݂��m�F����
					if(PlayDataManager.CheckCardEntry() == true) then
						-- ���̃J�[�h�̓G���g���[�ς݂Ȃ̂ŃG���[
						this.error_code_ = CardTouchError.kSameCard

						-- �ǂݍ��ݒ������
						NetAccessWindow.Close()
						TSound:StopSlot(kEntrySoundSlot_CautionVoice1)
						this.state_:SetState("ToError")
					else
						-- �������Ă���̂ŃT�[�o�[�փ��N�G�X�g�𓊂���
						NetAccess.StartBAIDCheck()
						this.state_:SetState("WaitNetAccess")
					end
				else
					-- ���s�̗��R���擾
					this.error_code_ = BanaPass.GetCardTouchError()

					-- �^�C���A�E�g�͂�蒼���H
--			BanaPass.StartCardTouch()

					-- �ǂݍ��ݒ������
					NetAccessWindow.Close()
					TSound:StopSlot(kEntrySoundSlot_CautionVoice1)
					this.state_:SetState("ToError")
				end
			end
		end

		this.state_.func_["WaitNetAccess"] = function()
			local ret_netaccess = NetAccess.GetNetAccessStatus()
			if(ret_netaccess == GameConnectStatus.kSuccess) then
				-- �ǂݍ��ݒ������
				NetAccessWindow.Close()
				TSound:StopSlot(kEntrySoundSlot_CautionVoice1)

				-- ������
				this.state_:SetState("ToSuccess")
			end
			if(ret_netaccess == GameConnectStatus.kError) then
				-- ���s�̗��R���擾
				this.error_code_ = BanaPass.GetCardTouchError()
				-- �ǂݍ��ݒ������
				NetAccessWindow.Close()
				TSound:StopSlot(kEntrySoundSlot_CautionVoice1)
				this.state_:SetState("ToError")
			end
		end


		this.state_.func_["ToSuccess"] = function()
			if(NetAccessWindow.IsPlay() == false) then
				NetAccessWindow.StartSuccess("connectserver_ok","connectserver_ok_sub")
				-- �r�d�u�o�i�p�X�|�[�g�ǂݍ��ݐ����v
				TSound:Play("se_common_v12a","card_success")

				this.state_:SetState("Success")
			end
		end
		this.state_.func_["Success"] = function()
			if(this.state_.count_ > (Common.FPS * 2.0)) then
				NetAccessWindow.Close()
				this.state_:SetState("SuccessToEnd")
			end
		end
		this.state_.func_["SuccessToEnd"] = function()
			if(NetAccessWindow.IsPlay() == false) then
				NetAccessWindow.CloseAll()
				this.result_reserve_ = 2
				this.state_:SetState("EndWait")
			end
		end

		this.state_.func_["ToError"] = function()
			if(NetAccessWindow.IsPlay() == false) then
				-- �f�t�H���g�u�ʐM�Ɏ��s���܂����v
				local key_title = "connectserver_error"
				local key_sub = ""

				-- �G���[�̎�ނŕ\����ς���
				-- �u���̃J�[�h�͎g�p�ł��܂���v
				if(this.error_code_ == CardTouchError.kDataFail) then
					key_title = "card_available_error"
					key_sub = "card_available_error_sub"
				end
				-- �u��������ƃ^�b�`���Ă��������v
				if(this.error_code_ == CardTouchError.kReadError) then
					key_title = "card_touch_error"
					key_sub = ""
				end
				-- �u���̃J�[�h�͑Ή����Ă��܂���v
				if(this.error_code_ == CardTouchError.kCardFail) then
					key_title = "card_compatible_error"
					key_sub = "card_compatible_error_sub"
				end
				-- �u�ǂݍ��݂Ɏ��s���܂����v
				if(this.error_code_ == CardTouchError.kCardError) then
					key_title = "card_read_error"
					key_sub = ""
				end
				-- �u���̃f�[�^�͂��łɓǂݍ���ł��܂��v
				if(this.error_code_ == CardTouchError.kSameCard) then
					key_title = "card_samedata_error"
					key_sub = "card_samedata_error_sub"
				end
				-- �u�X�������ԁv
				if(this.error_code_ == CardTouchError.kClosing) then
					key_sub = "card_closing_sub"
				end
				-- �u�X���v
				if(this.error_code_ == CardTouchError.kClosed) then
					key_sub = "card_closed_sub"
				end
				-- �u�����e�i���X�O�v
				if(this.error_code_ == CardTouchError.kBeforeMaintenance) then
					key_sub = "card_beforemaintenance_sub"
				end
				-- �u�����e�i���X���v
				if(this.error_code_ == CardTouchError.kUnderMaintenance) then
					key_sub = "card_undermaintenance_sub"
				end

				NetAccessWindow.StartError(key_title,key_sub)
				-- �r�d�u�o�i�p�X�|�[�g�ǂݍ��ݎ��s�v
				TSound:Play("se_common_v12a","card_error")

				this.state_:SetState("Error")
			end
		end
		this.state_.func_["Error"] = function()
			if(this.state_.count_ > (Common.FPS * 2.0)) then
				NetAccessWindow.Close()
				this.state_:SetState("ErrorToEnd")
			end
		end
		this.state_.func_["ErrorToEnd"] = function()
			if(NetAccessWindow.IsPlay() == false) then
				NetAccessWindow.CloseAll()
				this.result_reserve_ = -1
				this.state_:SetState("EndWait")
			end
		end

		this.state_.func_["EndWait"] = function()
			if(NetAccessWindow.IsPlayAll() == false) then
				this.result_ = this.result_reserve_

				-- �������I�����
				this.state_:SetState("End")
			end
		end
		this.state_.func_["End"] = function()
		end
	end,
	-- �J�n
	CardTouchWaitStart = function(this,resetFlag)
		NetAccessWindow.Wait()

		this.state_:SetState("CardTouchWait")
		this.result_ = 0

		-- �J�[�h�^�b�`�J�n
		if(resetFlag == true) then
			BanaPass.StartCardTouch()
		end

		-- �l�b�g���[�N�A�N�Z�X��ԃN���A
		NetAccess.ResetNetAccessStatus()
	end,
	-- �I��
	CardTouchWaitFinish = function(this)
--		NetAccessWindow.CloseAll()	-- closeall���ƈÓ]��ʂ���̃t�F�[�h�C���Ȃ̂ŕs�K�؂��ۂ�
		NetAccessWindow.Wait()

		-- �J�[�h�^�b�`�I��
		BanaPass.FinishCardTouch()

		this.state_:SetState("End")

		this.result_ = 0
		this.result_reserve_ = 0
	end,

	-- �X�V
	Update = function(this)
		-- �X�e�[�g���s
		this.state_:Update()

		-- 0:�������ĂȂ�
		-- 1:������
		-- 2:����
		-- -1:�G���[
		return this.result_
	end,


}
