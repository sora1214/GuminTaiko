-- �g���N���X��ǂݍ���
require("common.State")
require("common.Sound")
require("menu.game_setting.game_setting_panel")


-- ���̃N���X
Main = {
	m_State = State.New("GameSetting"),

	kCURSOR_MIN = GameSettingMode.BtnType,
	kCURSOR_MAX = (GameSettingMode.StaffRoll + 1),

	m_CursorPos = 1,
	m_BG_Scroll = false,

	m_MainMc,
	m_TitleMc,
	m_BGMc,

	Init = function(this)

		-- �X�e�[�g�}�V����g�ݗ��ĂĂ����A���ۂɎ��s�����̂̓X�e�[�g���������s����Ƃ�
		this.m_State.Func["Begin"] = function()
			-- �e��p�[�c�ǂݍ���
			Lumen.LoadMovie("lumen/system/title_signage","title")

			Debug.PrintFrame()

			this.m_State:SetState("Loading")
		end
		this.m_State.Func["Loading"] = function()
			if (Lumen.IsLoadMovieFinish() == true) then
				-- ���[�r�[�N���b�v�擾
				this.m_MainMc = Lumen.GetMovieClip("main",true)
				this.m_TitleMc = Lumen.GetMovieClip("main/title",false)		-- ���[�g��MC����c���[��S������
				-- ��Ɠ������삷����́�
					-- this.m_TitleMc = Lumen.GetMovieClip("title",true)		-- search_descendant���g���Ă���̂Ń��[�g�����ӂȂ猩����
					-- this.m_TitleMc = this.m_MainMc:GetChildMc("title",false)	-- ���łɎ擾�������[�r�[�N���b�v�̎q���������悤�Ɏ���
				-- �����܂�
				this.m_BGMc = Lumen.GetMovieClip("main/bg_mc",true)

				-- ���낢��J�n���Ă���
				-- ���[�g��MC�Đ�
				Lumen.Play()
				-- ���C��MC
				this.m_MainMc:Play()
				-- �p�l��
				Panel:Play()
				-- �w�i
				this.m_BGMc:GotoAndPlay("start_bg")

				-- �w�i�X�N���[��
				this.m_BG_Scroll = true

				-- �^�C�g���ݒ�
				this.m_TitleMc:GotoAndPlay("title_small_mc","start_title")
				this.m_TitleMc:SetText("title_small_mc/text_title_small_mc","text_title_small","mode_select_configuration")

				-- BGM�Đ�
				this:StartBGM();

				this.m_State:SetState("Start")
			end
		end

		this.m_State.Func["Start"] = function()
			this.m_State:SetState("PanelIntro")
		end
		this.m_State.Func["PanelIntro"] = function()
			-- �p�l���J�n
			Panel:IntroStart()
			this.m_State:SetState("PanelIntroWait")
		end
		this.m_State.Func["PanelIntroWait"] = function()
			-- �p�l�����肪����������
			if (Panel:IsFinishIntroAction() == true) then
				-- Help�p�l��
				Panel:OpenHelpMessage()
				Panel:SetHelpMessage(this.m_CursorPos)
				-- �J�[�\���ʒu�̃p�l����ON��
				Panel:PanelOn(this.m_CursorPos)

				this.m_State:SetState("TopMain")
			end
		end

		this.m_State.Func["TopMain"] = function()
			-- �L�[����
			if (Input.GetTrigger(Input.ALLPLAYER_OK) == true) then
				-- ����

				-- �p�l������A�N�V����
				Panel:DecideCursor(this.m_CursorPos)

				-- �J�[�\���ʒu
--				if((this.m_CursorPos == GameSettingMode.BtnType) or (this.m_CursorPos == GameSettingMode.Sound) or (this.m_CursorPos == GameSettingMode.Net)) then
				if(this.m_CursorPos == GameSettingMode.BtnType) then
					-- �p�l���̃w���v������
					Panel:CloseHelpMessage()
					this.m_State:SetState("DecideCursorAction")
				elseif(this.m_CursorPos == GameSettingMode.Tutorial) then
					this.m_State:SetState("TutorialIn")
				elseif(this.m_CursorPos == GameSettingMode.StaffRoll) then
					this.m_State:SetState("StaffRollIn")
				end

				-- �r�d
				TSound:PlayDecide()

			elseif (Input.GetTrigger(Input.ALLPLAYER_RIGHT) == true) then
				-- ��
				local oldID = this.m_CursorPos

				this.m_CursorPos = this.m_CursorPos + 1
				if(this.m_CursorPos >= this.kCURSOR_MAX) then
					this.m_CursorPos = this.kCURSOR_MIN
				end

				-- �p�l���؂�ւ�
				Panel:ChangePanel(oldID,this.m_CursorPos)

				-- �r�d
				TSound:PlaySelect();

			elseif (Input.GetTrigger(Input.ALLPLAYER_LEFT) == true) then
				-- ��
				local oldID = this.m_CursorPos

				this.m_CursorPos = this.m_CursorPos - 1
				if(this.m_CursorPos < this.kCURSOR_MIN) then
					this.m_CursorPos = (this.kCURSOR_MAX - 1)
				end

				-- �p�l���؂�ւ�
				Panel:ChangePanel(oldID,this.m_CursorPos)

				-- �r�d
				TSound:PlaySelect();
			end
		end

		this.m_State.Func["DecideCursorAction"] = function()
			-- �p�l���̌���J�[�\���̓��삪����������p�l���̂͂���A�j���[�V�����J�n
			if (Panel:IsFinishDecideCursorAction() == true) then
--				if((this.m_CursorPos == GameSettingMode.BtnType) or (this.m_CursorPos == GameSettingMode.Sound) or (this.m_CursorPos == GameSettingMode.Net)) then
				if(this.m_CursorPos == GameSettingMode.BtnType) then
					Panel:Out()
					this.m_State:SetState("PanelOutAction")
				else
					-- �J�[�\���ʒu�̃p�l����ON��
					Panel:PanelOn(this.m_CursorPos)
					this.m_State:SetState("TopMain")
				end
			end
		end
		this.m_State.Func["PanelOutAction"] = function()
			-- �p�l���̂͂���A�j���[�V����������������J�[�\���ʒu�ŕ��򂷂�
			if (Panel:IsFinishOutAction() == true) then
				if(this.m_CursorPos == GameSettingMode.BtnType) then
-- �������炱�̃V�[�����ł̕���


				end
			end
		end

		this.m_State.Func["TutorialIn"] = function()
			-- ���̃��[�h���w��
			NextMode = GameSettingMode.Return
			this.m_State:SetState("EndTimeWait")
		end
		this.m_State.Func["StaffRollIn"] = function()
			-- ���̃��[�h���w��
			NextMode = GameSettingMode.StaffRoll
			this.m_State:SetState("EndTimeWait")
		end

		this.m_State.Func["EndTimeWait"] = function()
			if(this.m_State.Count >= 30) then
				Common.LuaFinish()
				this.m_State:SetState("End")
			end
		end
		this.m_State.Func["End"] = function()
			this.m_BG_Scroll = false
		end


		-- ���W���[���������A����͂����Ŏ��s�����
		Panel:Init()
	end,

	Update = function(this)
		-- �p�b�h�̍X�V

		-- �X�e�[�g����
		this.m_State:Update()

		-- ���W���[���X�V
		Panel:Update()

		-- �w�i�X�N���[��
		this:ScrollBG()
	end,

	ScrollBG = function(this)
		if (this.m_BG_Scroll == true) then
			this.m_BGMc:AddPosXArea("scroll_bg_mc/scroll_bg",-0.5,-3840.0,0.0)
		end
	end,

	StartBGM = function(this)
		TSound:Play("jingle_config","jingle");
	end,
	StopBGM = function(this)
		TSound:StopBank("jingle_config");
	end,
}
