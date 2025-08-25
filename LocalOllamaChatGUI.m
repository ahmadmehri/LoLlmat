function LocalOllamaChatGUI
close all force hidden;
clc;
evalin('base', 'clear;');

% Create main figure
fig = uifigure('Name', 'Local Ollama Chat', 'Position', [100 100 1000 700]);
movegui(fig, 'center');

% Initialize UserData with default settings (model will be set after detection)
fig.UserData = struct(...
    'apiUrl', "http://localhost:11434/api/generate",...
    'httpOptions', weboptions('MediaType', 'application/json',...
    'RequestMethod', 'post',...
    'ArrayFormat', 'json',...
    'Timeout', 300),...
    'messages', struct('role', {'system'}, 'content', {'You are a helpful assistant.'}),...
    'currentFiles', {{}},...
    'model', '',...  % Will be set after model detection
    'systemPrompt', 'You are a helpful assistant.',...
    'modelOptions', struct(...
    'temperature', 0.5,...
    'top_p', 0.5,...
    'top_k', 40,...
    'num_ctx', 2048,...
    'seed', 0,...
    'num_predict', 128),...
    'connectionStatus', 'unknown',...
    'availableModels', {{}});

% Chat history display
% historyBox = uitextarea(fig,...
%     'Position', [20 180 960 500],...
%     'Editable', false,...
%     'WordWrap', true,...
%     'FontSize', 12,...
%     'BackgroundColor', [1 1 1]);
historyBox = uihtml(fig,...
    'Position', [20 180 960 500],...
    'HTMLSource', '<html><body style="font-family: Arial; font-size: 12px; background-color: white; padding: 10px;"></body></html>');

% File upload panel
filePanel = uipanel(fig, 'Title', 'File Upload',...
    'Position', [20 35 400 140],...
    'BackgroundColor', [0.95 0.95 0.95]);

uibutton(filePanel, 'push',...
    'Text', 'Browse Files',...
    'Position', [10 80 100 30],...
    'ButtonPushedFcn', @(btn,event) browseFiles);

fig.UserData.fileList = uilistbox(filePanel,...
    'Position', [120 10 270 100],...
    'Multiselect', 'on');

% Input panel
inputPanel = uipanel(fig, 'Title', 'Chat Input',...
    'Position', [430 35 550 140],...
    'BackgroundColor', [0.95 0.95 0.95]);

inputField = uieditfield(inputPanel, 'text',...
    'Position', [10 10 400 100],...
    'Placeholder', 'Type your message here...',...
    'FontSize', 12);

sendButton = uibutton(inputPanel, 'push',...
    'Text', 'Send',...
    'Position', [420 70 115 40],...
    'FontSize', 14,...
    'BackgroundColor', [0.3 0.6 1],...
    'FontColor', [1 1 1],...
    'ButtonPushedFcn', @(btn,event) sendMessage);

% Control buttons
uibutton(inputPanel, 'push',...
    'Text', 'New Chat',...
    'Position', [440 10 70 20],...
    'FontSize', 12,...
    'BackgroundColor', [0.4 0.8 0.4],...
    'FontColor', [1 1 1],...
    'ButtonPushedFcn', @(btn,event) handleNewChat);

uibutton(fig, 'push',...
    'Text', 'Settings',...
    'Position', [880 670 100 25],...
    'FontSize', 12,...
    'BackgroundColor', [0.8 0.8 0.8],...
    'ButtonPushedFcn', @(btn,event) openSettings(fig));

% Initialize connection and model detection
initializeConnection();

% Callback functions
    function initializeConnection()
        % Show initialization message
        updateHistory('system', 'Initializing connection to Ollama...');

        % Test connection and get available models
        [isConnected, availableModels, errorMsg] = testOllamaConnection();

        if isConnected && ~isempty(availableModels)
            fig.UserData.connectionStatus = 'connected';
            fig.UserData.availableModels = availableModels;

            % Select the best available model
            selectedModel = selectBestModel(availableModels);
            fig.UserData.model = selectedModel;

            updateHistory('system', sprintf('Connected to Ollama successfully! Found %d models.', length(availableModels)));
            updateHistory('system', sprintf('Using model: %s', selectedModel));

            % Show available models
            modelList = strjoin(availableModels, ', ');
            updateHistory('system', sprintf('Available models: %s', modelList));

        elseif isConnected && isempty(availableModels)
            fig.UserData.connectionStatus = 'no_models';
            showNoModelsDialog();

        else
            fig.UserData.connectionStatus = 'disconnected';
            showConnectionErrorDialog(errorMsg);
        end
    end

    function [isConnected, models, errorMsg] = testOllamaConnection()
        isConnected = false;
        models = {};
        errorMsg = '';

        try
            % Test connection by trying to get the list of models
            testOptions = weboptions(...
                'RequestMethod', 'get',...
                'Timeout', 10,...
                'ContentType', 'json');

            apiUrl = strrep(fig.UserData.apiUrl, '/api/generate', '/api/tags');
            response = webread(apiUrl, testOptions);

            if isfield(response, 'models') && ~isempty(response.models)
                isConnected = true;
                models = {response.models.name};
                % Remove duplicates and sort
                models = unique(models, 'stable');
            else
                isConnected = true; % Connection works but no models
                models = {};
            end

        catch ME
            errorMsg = ME.message;
        end
    end

    function selectedModel = selectBestModel(models)
        % Priority list of preferred models (in order of preference)
        preferredModels = {
            'llama3.2-vision:latest',
            'llama3.2:latest',
            'llama3.1:latest',
            'llama3:latest',
            'llama2:latest',
            'mistral:latest',
            'codellama:latest'
            };

        % Check if any preferred model is available
        for i = 1:length(preferredModels)
            if ismember(preferredModels{i}, models)
                selectedModel = preferredModels{i};
                return;
            end
        end

        % Check for variants (without :latest tag)
        for i = 1:length(preferredModels)
            baseModel = strrep(preferredModels{i}, ':latest', '');
            for j = 1:length(models)
                if startsWith(models{j}, baseModel)
                    selectedModel = models{j};
                    return;
                end
            end
        end

        % If no preferred model found, use the first available
        if ~isempty(models)
            selectedModel = models{1};
        else
            selectedModel = 'llama3.2-vision:latest'; % Fallback
        end
    end

    function showNoModelsDialog()
        noModelsFig = uifigure('Name', 'No Models Found', 'Position', [400 300 500 350]);
        movegui(noModelsFig, 'center');

        % Title
        uilabel(noModelsFig, 'Position', [20 300 460 30],...
            'Text', 'Ollama Connected - No Models Installed',...
            'FontSize', 16, 'FontWeight', 'bold',...
            'FontColor', [0.8 0.4 0]);

        % Main message
        uilabel(noModelsFig, 'Position', [20 250 460 40],...
            'Text', 'Ollama is running but no models are installed.',...
            'FontSize', 12);

        % Instructions
        uilabel(noModelsFig, 'Position', [20 210 460 30],...
            'Text', 'To install a model, run one of these commands in your terminal:',...
            'FontSize', 11, 'FontColor', [0.3 0.3 0.3]);

        % Command examples
        uilabel(noModelsFig, 'Position', [30 170 440 25],...
            'Text', 'ollama pull llama3.2-vision:latest',...
            'FontSize', 10, 'FontName', 'Courier New',...
            'BackgroundColor', [0.95 0.95 0.95]);

        uilabel(noModelsFig, 'Position', [30 140 440 25],...
            'Text', 'ollama pull llama3.2:latest',...
            'FontSize', 10, 'FontName', 'Courier New',...
            'BackgroundColor', [0.95 0.95 0.95]);

        uilabel(noModelsFig, 'Position', [30 110 440 25],...
            'Text', 'ollama pull mistral:latest',...
            'FontSize', 10, 'FontName', 'Courier New',...
            'BackgroundColor', [0.95 0.95 0.95]);

        % Buttons
        uibutton(noModelsFig, 'push',...
            'Position', [200 60 100 30],...
            'Text', 'Retry',...
            'ButtonPushedFcn', @(~,~) retryConnection(noModelsFig));

        uibutton(noModelsFig, 'push',...
            'Position', [320 60 100 30],...
            'Text', 'Continue',...
            'ButtonPushedFcn', @(~,~) continueWithoutModel(noModelsFig));

        % Disable send button until model is available
        sendButton.Enable = 'off';
        sendButton.Text = 'No Model';

        updateHistory('system', 'Chat disabled - No models available');
    end

    function showConnectionErrorDialog(errorMsg)
        errorFig = uifigure('Name', 'Connection Error', 'Position', [400 300 500 400]);
        movegui(errorFig, 'center');

        % Title
        uilabel(errorFig, 'Position', [20 350 460 30],...
            'Text', 'Cannot Connect to Ollama',...
            'FontSize', 16, 'FontWeight', 'bold',...
            'FontColor', [1 0 0]);

        % Error message
        uilabel(errorFig, 'Position', [20 310 460 30],...
            'Text', sprintf('Error: %s', errorMsg),...
            'FontSize', 11, 'FontColor', [0.6 0.6 0.6]);

        % Instructions
        uilabel(errorFig, 'Position', [20 270 460 30],...
            'Text', 'Please ensure Ollama is installed and running.',...
            'FontSize', 12);

        % Installation link
        uilabel(errorFig, 'Position', [20 240 460 30],...
            'Text', 'Download from: https://ollama.com/',...
            'FontSize', 11, 'FontColor', [0 0 1]);

        % Start instructions
        uilabel(errorFig, 'Position', [20 200 460 30],...
            'Text', 'If installed, start Ollama by running:',...
            'FontSize', 11, 'FontColor', [0.3 0.3 0.3]);

        uilabel(errorFig, 'Position', [30 165 440 25],...
            'Text', 'ollama serve',...
            'FontSize', 11, 'FontName', 'Courier New',...
            'BackgroundColor', [0.95 0.95 0.95]);

        uilabel(errorFig, 'Position', [20 130 460 25],...
            'Text', 'Or check if it''s running on a different port/address.',...
            'FontSize', 10, 'FontColor', [0.5 0.5 0.5]);

        % Buttons
        uibutton(errorFig, 'push',...
            'Position', [150 80 100 30],...
            'Text', 'Retry',...
            'ButtonPushedFcn', @(~,~) retryConnection(errorFig));

        uibutton(errorFig, 'push',...
            'Position', [270 80 100 30],...
            'Text', 'Settings',...
            'ButtonPushedFcn', @(~,~) openSettingsFromError(errorFig));

        % Disable send button
        sendButton.Enable = 'off';
        sendButton.Text = 'Offline';

        updateHistory('system', 'Chat disabled - Cannot connect to Ollama');
    end

    function retryConnection(dialogFig)
        close(dialogFig);
        updateHistory('system', 'Retrying connection...');
        initializeConnection();
    end

    function continueWithoutModel(dialogFig)
        close(dialogFig);
        % Set a placeholder model
        fig.UserData.model = 'no-model-available';
        updateHistory('system', 'Continuing without model - Install a model and restart');
    end

    function openSettingsFromError(dialogFig)
        close(dialogFig);
        openSettings(fig);
    end

    function browseFiles
        [files, path] = uigetfile(...
            {'*.png;*.jpg;*.jpeg;*.pdf;*.docx;*.txt',...
            'Supported Files (*.png, *.jpg, *.pdf, *.docx, *.txt)'},...
            'MultiSelect', 'on');

        if ~isequal(files, 0)
            if ischar(files)
                files = {files};
            end
            fullpaths = fullfile(path, files);
            fig.UserData.currentFiles = fullpaths;
            fig.UserData.fileList.Items = cellstr(files);
        end
    end

    function sendMessage
        % Check if we have a valid model
        if strcmp(fig.UserData.connectionStatus, 'disconnected') || ...
                strcmp(fig.UserData.connectionStatus, 'no_models')
            uialert(fig, 'Cannot send message: Ollama not connected or no models available', 'Connection Error');
            return;
        end

        prompt = inputField.Value;
        files = fig.UserData.currentFiles;

        if isempty(prompt) && isempty(files)
            return;
        end

        % Disable the Send button and show "Busy" text
        sendButton.Enable = 'off';
        busyText = uilabel(inputPanel, 'Text', 'Busy..',...
            'Position', [420 40 115 20],...
            'FontSize', 12,...
            'FontColor', [1 0 0],...
            'HorizontalAlignment', 'center');

        % Update GUI with user prompt immediately
        if ~isempty(prompt)
            updateHistory('user', prompt);
        end
        if ~isempty(files)
            for i = 1:length(files)
                updateHistory('system', ['Uploaded file: ' files{i}]);
            end
        end

        % Clear input fields
        inputField.Value = '';
        fig.UserData.currentFiles = {};
        fig.UserData.fileList.Items = {};

        % Process message asynchronously
        drawnow; % Force UI update
        processRequest(prompt, files, @() onRequestComplete(busyText));
    end

    function handleNewChat
        % Reset chat history to initial state with current system prompt
        fig.UserData.messages = struct('role', {'system'}, 'content', {fig.UserData.systemPrompt});

        % Clear the chat history display
        historyBox.HTMLSource = '<html><body style="font-family: Arial; font-size: 12px; background-color: white; padding: 10px;"></body></html>';

        % Reset file upload components
        fig.UserData.currentFiles = {};
        fig.UserData.fileList.Items = {};

        % Add system message confirmation
        updateHistory('system', sprintf('New chat session started with model: %s', fig.UserData.model));
    end

    function updateHistory(role, content)
        % Get current HTML content
        currentHTML = historyBox.HTMLSource;

        % Extract body content (remove html/body tags for manipulation)
        bodyStart = strfind(currentHTML, '<body');
        bodyEnd = strfind(currentHTML, '</body>');

        if ~isempty(bodyStart) && ~isempty(bodyEnd)
            % Find the end of the opening body tag
            bodyTagEnd = strfind(currentHTML(bodyStart:end), '>');
            bodyContentStart = bodyStart + bodyTagEnd(1);
            bodyContent = currentHTML(bodyContentStart:bodyEnd-1);
        else
            bodyContent = '';
        end

        % Create new entry based on role
        switch role
            case 'user'
                newEntry = sprintf('<div style="color: red; font-weight: bold; margin: 5px 0;">You: %s</div>', ...
                    strrep(strrep(content, '<', '&lt;'), '>', '&gt;'));
            case 'assistant'
                separator = '<hr style="border: 1px solid #ccc; margin: 10px 0;">';
                newEntry = sprintf('%s<div style="color: blue; margin: 5px 0;"><strong>Assistant:</strong> %s</div>%s', ...
                    separator, strrep(strrep(content, '<', '&lt;'), '>', '&gt;'), separator);
            case 'system'
                newEntry = sprintf('<div style="color: gray; font-style: italic; margin: 5px 0;">System: %s</div>', ...
                    strrep(strrep(content, '<', '&lt;'), '>', '&gt;'));
        end

        % Update HTML content
        newHTML = sprintf('<html><body style="font-family: Arial; font-size: 12px; background-color: white; padding: 10px;">%s%s</body></html>', ...
            bodyContent, newEntry);
        historyBox.HTMLSource = newHTML;

        % Auto-scroll to bottom (add JavaScript)
        scrollScript = '<script>window.scrollTo(0, document.body.scrollHeight);</script>';
        historyBox.HTMLSource = strrep(historyBox.HTMLSource, '</body>', [scrollScript '</body>']);
    end


    function processRequest(prompt, files, completionCallback)
        try
            % Process files
            fullPrompt = '';
            imageEncodings = {};

            if ~isempty(files)
                for i = 1:length(files)
                    [~, ~, ext] = fileparts(files{i});
                    if ismember(ext, {'.png', '.jpg', '.jpeg'})
                        base64Image = encode_image(files{i});
                        imageEncodings{end+1} = base64Image;
                    else
                        textContent = extractDocumentText(files{i});
                        fullPrompt = [fullPrompt ' [Document: ' textContent '] '];
                    end
                end
            end
            fullPrompt = [fullPrompt prompt];

            % Update system prompt if changed
            if ~strcmp(fig.UserData.messages(1).content, fig.UserData.systemPrompt)
                fig.UserData.messages(1).content = fig.UserData.systemPrompt;
            end

            % Add user message to history
            newUserMsg = struct('role', 'user', 'content', fullPrompt);
            fig.UserData.messages(end+1) = newUserMsg;

            % Build request with current settings
            data = struct(...
                'model', fig.UserData.model,...
                'prompt', buildPrompt(fig.UserData.messages),...
                'stream', false,...
                'options', fig.UserData.modelOptions...
                );

            % Add images if present
            if ~isempty(imageEncodings)
                data.images = imageEncodings;
            end

            % Send request with current timeout
            response = webwrite(fig.UserData.apiUrl, data, fig.UserData.httpOptions);
            aiResponse = response.response;

            % Update chat history
            updateHistory('assistant', aiResponse);
            newAiMsg = struct('role', 'assistant', 'content', aiResponse);
            fig.UserData.messages(end+1) = newAiMsg;

        catch ME
            updateHistory('system', ['Error: ' ME.message]);

            % If model not found error, suggest refreshing models
            if contains(ME.message, 'not found') || contains(ME.message, 'model')
                updateHistory('system', 'Model may not be available. Try refreshing in Settings.');
            end
        end

        % Call the completion callback to re-enable the Send button
        completionCallback();
    end

    function onRequestComplete(busyText)
        % Re-enable the Send button and remove "Busy" text
        sendButton.Enable = 'on';
        delete(busyText);
        drawnow; % Force UI update
    end

    function openSettings(parentFig)
        existingFigs = findall(0, 'Type', 'Figure', 'Name', 'Settings');
        if ~isempty(existingFigs)
            close(existingFigs);
        end

        try
            settingsFig = uifigure('Name', 'Settings', 'Position', [300 300 550 600],...
                'CloseRequestFcn', @closeSettings);
            movegui(settingsFig, 'center');

            % Create tab group with space for save button
            tabGroup = uitabgroup(settingsFig, 'Position', [10 50 520 550]);

            % Connection Tab
            connTab = uitab(tabGroup, 'Title', 'Connection');
            createConnectionTab(connTab, parentFig, settingsFig);

            % Model Tab
            modelTab = uitab(tabGroup, 'Title', 'Model Settings');
            try
                createModelTab(modelTab, parentFig, settingsFig);
            catch ME
                % Display an error message in the Model tab if the tab creation fails
                errorGrid = uigridlayout(modelTab, [2 1]);
                errorGrid.RowHeight = {'1x', '1x'};

                uilabel(errorGrid, 'Text', 'Error loading model settings:', 'FontColor', [1 0 0]);
                uilabel(errorGrid, 'Text', ME.message);

                % Log the error details
                disp(['Error in createModelTab: ' ME.message]);
                disp(getReport(ME));
            end

            % Add global save button
            uibutton(settingsFig, 'push',...
                'Position', [235 10 100 30],...
                'Text', 'Save All',...
                'ButtonPushedFcn', @(src,event) saveAllSettings(parentFig, settingsFig));
            % Add global help button
            uibutton(settingsFig, 'push',...
                'Position', [485 578 40 20],...
                'Text', 'Help',...
                'ButtonPushedFcn', @(src,event) openHelpWindow());
        catch ME
            % If the settings window fails to open entirely, show an error dialog
            errordlg(['Failed to open settings: ' ME.message], 'Settings Error');
            disp(['Error in openSettings: ' ME.message]);
            disp(getReport(ME));
        end
    end

    function createConnectionTab(tab, parentFig, settingsFig)
        grid = uigridlayout(tab, [7 2]);
        grid.RowHeight = {'fit','fit','fit','fit','fit', 'fit', 'fit'};
        grid.ColumnWidth = [120 350];
        grid.Padding = [10 10 10 10];

        % API URL
        uilabel(grid, 'Text', 'API URL:');
        apiUrlField = uieditfield(grid, 'text',...
            'Value', parentFig.UserData.apiUrl,...
            'Tag', 'apiUrl');
        apiUrlField.Layout.Row = 1;
        apiUrlField.Layout.Column = 2;

        % Timeout
        uilabel(grid, 'Text', 'Timeout (seconds):');
        timeoutField = uispinner(grid,...
            'Limits', [1 600],...
            'Value', parentFig.UserData.httpOptions.Timeout,...
            'Step', 1,...
            'Tag', 'timeoutSpinner');
        timeoutField.Layout.Row = 2;
        timeoutField.Layout.Column = 2;

        % Connection test
        testBtn = uibutton(grid, 'push',...
            'Text', 'Test Connection',...
            'ButtonPushedFcn', @testConnection);
        testBtn.Layout.Row = 3;
        testBtn.Layout.Column = [1 2];

        % Status indicators
        statusLight = uilamp(grid);
        statusLight.Layout.Row = 4;
        statusLight.Layout.Column = 1;

        statusText = uilabel(grid, 'Text', sprintf('Status: %s', parentFig.UserData.connectionStatus));
        statusText.Layout.Row = 4;
        statusText.Layout.Column = 2;

        % Refresh models button
        refreshBtn = uibutton(grid, 'push',...
            'Text', 'Refresh Models',...
            'ButtonPushedFcn', @refreshModels);
        refreshBtn.Layout.Row = 5;
        refreshBtn.Layout.Column = [1 2];

        % Models list
        uilabel(grid, 'Text', 'Available Models:', 'VerticalAlignment', 'top');
        modelsList = uilistbox(grid,...
            'Items', parentFig.UserData.availableModels);
        modelsList.Layout.Row = 6;
        modelsList.Layout.Column = 2;

        function testConnection(~,~)
            try
                tempOptions = weboptions(...
                    'RequestMethod', 'get',...
                    'Timeout', timeoutField.Value);

                testUrl = strrep(apiUrlField.Value, '/api/generate', '/api/tags');
                response = webread(testUrl, tempOptions);

                if isfield(response, 'models')
                    statusLight.Color = [0 1 0];
                    statusText.Text = sprintf('Connected! Found %d models', numel(response.models));
                else
                    error('Invalid response format');
                end
            catch ME
                statusLight.Color = [1 0 0];
                statusText.Text = ['Connection failed: ' ME.message];
            end
        end

        function refreshModels(~,~)
            [isConnected, availableModels, ~] = testOllamaConnection();
            if isConnected
                parentFig.UserData.availableModels = availableModels;
                modelsList.Items = availableModels;
                statusText.Text = sprintf('Refreshed: %d models found', length(availableModels));
            else
                statusText.Text = 'Failed to refresh models';
            end
        end
    end

    function createModelTab(tab, parentFig, settingsFig)
        grid = uigridlayout(tab, [12 2]);
        grid.RowHeight = repmat({'fit'}, 1, 12);
        grid.ColumnWidth = [120 350];
        grid.Padding = [10 10 10 10];

        % System Prompt
        uilabel(grid, 'Text', 'System Prompt:', 'VerticalAlignment', 'top');
        sysPromptArea = uitextarea(grid,...
            'Value', splitSystemPrompt(parentFig.UserData.systemPrompt),...
            'Tag', 'systemPrompt');
        sysPromptArea.Layout.Row = [1 3];
        sysPromptArea.Layout.Column = 2;

        % Model Selection - with error handling
        uilabel(grid, 'Text', 'Model:');

        % Use available models from connection check
        models = parentFig.UserData.availableModels;
        if isempty(models)
            models = {'No models available'};
        end

        % Safety check for current model
        currentModel = parentFig.UserData.model;
        if isempty(currentModel) || ~ischar(currentModel) && ~isstring(currentModel)
            if ~isempty(parentFig.UserData.availableModels)
                currentModel = parentFig.UserData.availableModels{1};
            else
                currentModel = 'No models available';
            end
        end

        % Ensure current model exists in the list
        if ~ismember(currentModel, models) && ~isempty(parentFig.UserData.availableModels)
            models{end+1} = currentModel;
        end

        % Create dropdown with validated values
        modelDropdown = uidropdown(grid,...
            'Items', models,...
            'Value', currentModel,...
            'Tag', 'modelSelector');
        modelDropdown.Layout.Row = 4;
        modelDropdown.Layout.Column = 2;

        % Model Parameters
        createParamControl(grid, 5, 'temperature', 'Temperature:', parentFig.UserData.modelOptions.temperature, 0, 1);
        createParamControl(grid, 6, 'top_p', 'Top P:', parentFig.UserData.modelOptions.top_p, 0, 1);
        createParamControl(grid, 7, 'top_k', 'Top K:', parentFig.UserData.modelOptions.top_k, 1, 100);
        createParamControl(grid, 8, 'num_ctx', 'Context Window:', parentFig.UserData.modelOptions.num_ctx, 512, 4096);
        createParamControl(grid, 9, 'num_predict', 'Max Tokens:', parentFig.UserData.modelOptions.num_predict, 1, 4096);
        createParamControl(grid, 10, 'seed', 'Seed:', parentFig.UserData.modelOptions.seed, 0, 99999);

        function createParamControl(parent, row, tag, label, value, minVal, maxVal)
            uilabel(parent, 'Text', label);
            controlGrid = uigridlayout(parent, [1 2],...
                'ColumnWidth', {'3x', '1x'},...
                'Tag', ['paramControl_' tag]);

            slider = uislider(controlGrid,...
                'Limits', [minVal maxVal],...
                'Value', value);
            spinner = uispinner(controlGrid,...
                'Limits', [minVal maxVal],...
                'Value', value,...
                'Step', 1);

            slider.ValueChangedFcn = @(src,~) set(spinner, 'Value', src.Value);
            spinner.ValueChangedFcn = @(src,~) set(slider, 'Value', src.Value);
        end
    end

    function saveAllSettings(parentFig, settingsFig)
        try
            % Capture original settings before changes
            originalSettings = struct(...
                'apiUrl', parentFig.UserData.apiUrl,...
                'httpOptions', parentFig.UserData.httpOptions,...
                'systemPrompt', parentFig.UserData.systemPrompt,...
                'model', parentFig.UserData.model,...
                'modelOptions', parentFig.UserData.modelOptions);

            % Get connection settings
            apiUrlField = findobj(settingsFig, 'Tag', 'apiUrl');
            timeoutField = findobj(settingsFig, 'Tag', 'timeoutSpinner');

            % Recreate HTTP options with explicit parameters
            parentFig.UserData.httpOptions = weboptions(...
                'MediaType', 'application/json',...
                'RequestMethod', 'post',...
                'ArrayFormat', 'json',...
                'Timeout', double(timeoutField.Value));

            % Update API URL
            parentFig.UserData.apiUrl = convertStringsToChars(apiUrlField.Value);

            % Get model components
            modelDropdown = findobj(settingsFig, 'Tag', 'modelSelector');
            sysPromptArea = findobj(settingsFig, 'Tag', 'systemPrompt');

            % Update model settings
            sysPromptValue = sysPromptArea.Value;
            if iscell(sysPromptValue)
                parentFig.UserData.systemPrompt = strjoin(sysPromptValue, '\n');
            else
                parentFig.UserData.systemPrompt = char(sysPromptValue);
            end

            % Update model if valid selection
            newModel = convertStringsToChars(modelDropdown.Value);
            if ~strcmp(newModel, 'No models available')
                parentFig.UserData.model = newModel;

                % Re-enable send button if model is now available
                if strcmp(sendButton.Text, 'No Model') || strcmp(sendButton.Text, 'Offline')
                    sendButton.Enable = 'on';
                    sendButton.Text = 'Send';
                end
            end

            % Update model parameters
            opts = parentFig.UserData.modelOptions;
            paramControls = findobj(settingsFig, '-regexp', 'Tag', 'paramControl');

            for i = 1:length(paramControls)
                tag = char(paramControls(i).Tag);
                value = double(paramControls(i).Children(2).Value);

                switch tag
                    case 'paramControl_temperature'
                        opts.temperature = value;
                    case 'paramControl_top_p'
                        opts.top_p = value;
                    case 'paramControl_top_k'
                        opts.top_k = value;
                    case 'paramControl_num_ctx'
                        opts.num_ctx = round(value);
                    case 'paramControl_num_predict'
                        opts.num_predict = round(value);
                    case 'paramControl_seed'
                        opts.seed = round(value);
                end
            end

            parentFig.UserData.modelOptions = opts;

            % Check if connection settings changed - if so, test new connection
            connectionChanged = ~strcmp(originalSettings.apiUrl, parentFig.UserData.apiUrl) || ...
                originalSettings.httpOptions.Timeout ~= parentFig.UserData.httpOptions.Timeout;

            if connectionChanged
                updateHistory('system', 'Connection settings changed. Testing new connection...');
                [isConnected, availableModels, errorMsg] = testOllamaConnection();

                if isConnected
                    parentFig.UserData.connectionStatus = 'connected';
                    parentFig.UserData.availableModels = availableModels;
                    updateHistory('system', sprintf('New connection successful! Found %d models.', length(availableModels)));

                    % Check if current model is still available
                    if ~ismember(parentFig.UserData.model, availableModels) && ~isempty(availableModels)
                        oldModel = parentFig.UserData.model;
                        parentFig.UserData.model = selectBestModel(availableModels);
                        updateHistory('system', sprintf('Model "%s" not available. Switched to "%s".', oldModel, parentFig.UserData.model));
                    end
                else
                    parentFig.UserData.connectionStatus = 'disconnected';
                    updateHistory('system', sprintf('Connection failed: %s', errorMsg));
                    sendButton.Enable = 'off';
                    sendButton.Text = 'Offline';
                end
            end

            % Detect changes and build message
            changes = {};

            % Check API URL
            if ~strcmp(originalSettings.apiUrl, parentFig.UserData.apiUrl)
                changes{end+1} = sprintf('API URL → "%s"', parentFig.UserData.apiUrl);
            end

            % Check Timeout
            if originalSettings.httpOptions.Timeout ~= parentFig.UserData.httpOptions.Timeout
                changes{end+1} = sprintf('Timeout → %d seconds', parentFig.UserData.httpOptions.Timeout);
            end

            % Check System Prompt
            if ~strcmp(originalSettings.systemPrompt, parentFig.UserData.systemPrompt)
                changes{end+1} = sprintf('System Prompt → "%s"', parentFig.UserData.systemPrompt);
            end

            % Check Model
            if ~strcmp(originalSettings.model, parentFig.UserData.model)
                changes{end+1} = sprintf('Model → "%s"', parentFig.UserData.model);
            end

            % Check Model Options
            fields = {'temperature', 'top_p', 'top_k', 'num_ctx', 'num_predict', 'seed'};
            for i = 1:numel(fields)
                field = fields{i};
                originalVal = originalSettings.modelOptions.(field);
                newVal = parentFig.UserData.modelOptions.(field);
                if originalVal ~= newVal
                    changes{end+1} = sprintf('%s → %g', field, newVal);
                end
            end

            % Create notification message
            if isempty(changes)
                msg = 'Settings updated successfully (no changes detected)';
            else
                msg = ['Settings updated successfully:' newline];
                msg = [msg strjoin(cellfun(@(c) ['• ' c], changes, 'UniformOutput', false), newline)];
            end

            close(settingsFig);
            updateHistory('system', msg);

        catch ME
            uialert(settingsFig, ME.message, 'Save Error');
        end
    end

    function closeSettings(src,~)
        delete(src);
    end

    function prompt = buildPrompt(messages)
        promptParts = cell(1, numel(messages));
        for i = 1:numel(messages)
            switch lower(messages(i).role)
                case 'system'
                    promptParts{i} = sprintf("System: %s", messages(i).content);
                case 'user'
                    promptParts{i} = sprintf("User: %s", messages(i).content);
                case 'assistant'
                    promptParts{i} = sprintf("Assistant: %s", messages(i).content);
            end
        end
        prompt = strjoin(string(promptParts), '\n');
    end

    function base64Image = encode_image(image_path)
        fid = fopen(image_path, 'rb');
        imageData = fread(fid, inf, '*uint8');
        fclose(fid);
        base64Image = matlab.net.base64encode(imageData);
    end

    function textContent = extractDocumentText(filePath)
        [~, ~, ext] = fileparts(filePath);
        textContent = 'Unsupported document format';
        try
            if strcmpi(ext, '.pdf') || strcmpi(ext, '.txt')
                textContent = extractFileText(filePath);
                textContent = char(textContent);
            elseif strcmpi(ext, '.docx')
                textContent = extractDocxText(filePath);
            end
        catch ME
            textContent = ['Error: ' ME.message];
        end
    end

    function text = extractDocxText(docxPath)
        tmpDir = tempname;
        mkdir(tmpDir);
        try
            unzip(docxPath, tmpDir);
            xmlPath = fullfile(tmpDir, 'word', 'document.xml');
            xmlText = fileread(xmlPath);
            tokens = regexp(xmlText, '<w:t[^>]*>([^<]*)</w:t>', 'tokens');
            text = strjoin([tokens{:}], ' ');
            rmdir(tmpDir, 's');
        catch ME
            text = ['DOCX Error: ' ME.message];
            try
                rmdir(tmpDir, 's');
            catch
            end
        end
    end

    function lines = splitSystemPrompt(prompt)
        if isempty(prompt)
            lines = {''};
            return;
        end

        if ischar(prompt)
            lines = regexp(prompt, '\n', 'split');
        elseif isstring(prompt)
            lines = strsplit(prompt, newline);
        else
            lines = {''};
        end

        % Handle empty result
        if isempty(lines)
            lines = {''};
        end
    end

end

 function openHelpWindow()
        % Create Help Window
        helpFig = uifigure('Name', 'Help Guide', ...
            'Position', [200 300 700 600]);
        movegui(helpFig, 'center');

        % Create Scrollable Panel (no longer scrollable)
        scrollPanel = uipanel(helpFig, ...
            'Position', [0 0 700 600], ...
            'Scrollable', 'off'); % Disable scrolling for the panel

        % Build HTML content using sprintf for proper concatenation
        helpText = sprintf([...
            '<html><div style="font-family:Arial; padding:15px; line-height:1.6">',...
            '<h1 style="color:#2c3e50; border-bottom:2px solid #3498db">Help Guide for Local Ollama Chat Settings</h1>',...
            '<p>Welcome to the <b>Local Ollama Chat</b> help page! Here, you''ll find explanations for all adjustable parameters in the settings menu.</p>',...
            '<hr>',...
            '<h2 style="color:#2980b9">1. Connection Settings</h2>',...
            '<h3>API URL</h3>',...
            '<ul>',...
            '<li>This is the URL of the local API endpoint used for communication with the AI model</li>',...
            '<li>Default: <code>http://localhost:11434/api/generate</code></li>',...
            '<li>Change this only if you are using a different server or port</li>',...
            '</ul>',...
            '<h3>Timeout (seconds)</h3>',...
            '<ul>',...
            '<li>Sets the maximum time the system waits for a response before giving up</li>',...
            '<li>Default: <code>300</code> seconds (5 minutes)</li>',...
            '<li>Increase if you experience timeout errors with large requests</li>',...
            '</ul>',...
            '<hr>',...
            '<h2 style="color:#2980b9">2. Model Settings</h2>',...
            '<h3>System Prompt</h3>',...
            '<ul>',...
            '<li>A predefined instruction for the AI model to guide its behavior</li>',...
            '<li>Example: <code>"You are a helpful assistant."</code></li>',...
            '<li>Modify this if you want the AI to respond differently (e.g., <code>"You are a coding assistant."</code>)</li>',...
            '</ul>',...
            '<h3>Model Selection</h3>',...
            '<ul>',...
            '<li>Choose from available AI models</li>',...
            '<li>Default: <code>llama3.2-vision:11b</code></li>',...
            '<li>The list updates based on models available in your local API</li>',...
            '</ul>',...
            '<hr>',...
            '<h2 style="color:#2980b9">3. Model Parameters</h2>',...
            '<p>These parameters affect the AI''s response style and generation behavior.</p>',...
            '<h3>Temperature (<code>0 to 1</code>)</h3>',...
            '<ul>',...
            '<li>Controls randomness in responses</li>',...
            '<li>Lower values (<code>0.1 - 0.3</code>): More predictable and focused answers</li>',...
            '<li>Higher values (<code>0.7 - 1.0</code>): More creative and varied responses</li>',...
            '<li>Default: <code>0.5</code> (balanced output)</li>',...
            '</ul>',...
            '<h3>Top-P (Nucleus Sampling) (<code>0 to 1</code>)</h3>',...
            '<ul>',...
            '<li>Limits AI choices to the most probable tokens</li>',...
            '<li>Lower values (<code>0.1 - 0.3</code>): More deterministic responses</li>',...
            '<li>Higher values (<code>0.7 - 1.0</code>): More diverse responses</li>',...
            '<li>Default: <code>0.5</code></li>',...
            '</ul>',...
            '<h3>Top-K (<code>1 to 100</code>)</h3>',...
            '<ul>',...
            '<li>Similar to Top-P but limits token selection to the top <b>K</b> most likely words</li>',...
            '<li>Lower values (<code>10 - 20</code>): More focused responses</li>',...
            '<li>Higher values (<code>50 - 100</code>): More variation in responses</li>',...
            '<li>Default: <code>40</code></li>',...
            '</ul>',...
            '<h3>Context Window Size (<code>num_ctx</code>) (<code>512 to 4096</code>)</h3>',...
            '<ul>',...
            '<li>Determines how much text the AI can remember in a conversation</li>',...
            '<li>Higher values (<code>2048 - 4096</code>): Better long-term memory but more processing time</li>',...
            '<li>Default: <code>2048</code></li>',...
            '</ul>',...
            '<h3>Max Tokens (<code>num_predict</code>) (<code>1 to 4096</code>)</h3>',...
            '<ul>',...
            '<li>Limits the number of tokens (words/characters) generated per response</li>',...
            '<li>Lower values (<code>50 - 200</code>): Shorter responses</li>',...
            '<li>Higher values (<code>500+</code>): Longer and more detailed responses</li>',...
            '<li>Default: <code>128</code></li>',...
            '</ul>',...
            '<h3>Seed</h3>',...
            '<ul>',...
            '<li>Sets a fixed value for reproducible results</li>',...
            '<li><code>0</code>: No fixed seed, responses vary</li>',...
            '<li>Any other number: Ensures consistent AI output across runs</li>',...
            '<li>Default: <code>0</code></li>',...
            '</ul>',...
            '<hr>',...
            '<h2 style="color:#2980b9">4. Save and Apply Settings</h2>',...
            '<ul>',...
            '<li>After adjusting parameters, click <b>Save All</b> to apply changes</li>',...
            '<li>Adjust settings based on your needs for better performance and response quality</li>',...
            '</ul>',...
            '<hr>',...
            '<p style="text-align:center">If you have any questions, feel free to reach out! Happy chatting! 😊<br>',...
            '<a href="https://rockbench.ir/">rockbench.ir</a></p>',...
            '</div></html>']);

        % Create HTML component with proper wrapping
        helpHtml = uihtml(scrollPanel, ...
            'Position', [10 10 680 580], ... % Adjusted height to fit within the panel
            'HTMLSource', helpText);

        % Add JavaScript to scroll to the top after loading
        helpHtml.HTMLSource = [helpText, ...
            '<script>window.scrollTo(0, 0);</script>'];
    end