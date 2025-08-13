function LocalOllamaRAGChat
close all force hidden;
clc;
evalin('base', 'clear;');

% Create main figure
fig = uifigure('Name', 'Local Ollama RAG Chat', 'Position', [100 100 1200 700]);
movegui(fig, 'center');

% Initialize UserData with RAG components
fig.UserData = struct(...
    'apiUrl', "http://localhost:11434/api/generate",...
    'embedUrl', "http://localhost:11434/api/embed",...
    'httpOptions', weboptions('MediaType', 'application/json',...
    'RequestMethod', 'post',...
    'ArrayFormat', 'json',...
    'Timeout', 300),...
    'messages', struct('role', {'system'}, 'content', {'You are a helpful assistant with access to uploaded documents.'}),...
    'currentFiles', {{}},...
    'model', '',...
    'embedModel', 'nomic-embed-text',...
    'systemPrompt', 'You are a helpful assistant with access to uploaded documents.',...
    'modelOptions', struct(...
    'temperature', 0.5,...
    'top_p', 0.5,...
    'top_k', 40,...
    'num_ctx', 2048,...
    'seed', 0,...
    'num_predict', -1),...% Changed from 128 to -1 for unlimited
    'connectionStatus', 'unknown',...
    'availableModels', {{}},...
    'availableEmbedModels', {{}},...
    'documentChunks', {{}},...
    'chunkEmbeddings', [],...
    'chunkMetadata', {{}},...
    'ragEnabled', true,...
    'maxRetrievals', 3,...
    'chunkSize', 500,... % Add this line
    'similarityThreshold', 0.1); % Add this line

% Chat history display
historyBox = uihtml(fig,...
    'Position', [20 180 760 500],...
    'HTMLSource', '<html><body style="font-family: Arial; font-size: 12px; background-color: white; padding: 10px;"></body></html>');

% RAG Knowledge Base Panel
ragPanel = uipanel(fig, 'Title', 'Knowledge Base',...
    'Position', [790 350 390 330],...
    'BackgroundColor', [0.95 0.95 1]);

uibutton(ragPanel, 'push',...
    'Text', 'Add Documents',...
    'Position', [10 275 120 30],...
    'ButtonPushedFcn', @(btn,event) addDocuments);

uibutton(ragPanel, 'push',...
    'Text', 'Clear KB',...
    'Position', [140 275 80 30],...
    'ButtonPushedFcn', @(btn,event) clearKnowledgeBase);

fig.UserData.ragToggle = uicheckbox(ragPanel,...
    'Text', 'Enable RAG',...
    'Position', [230 285 100 20],...
    'Value', true);

fig.UserData.kbList = uilistbox(ragPanel,...
    'Position', [10 50 360 220],...
    'Items', {});

ragStatusLabel = uilabel(ragPanel,...
    'Position', [10 20 360 25],...
    'Text', 'Knowledge Base: Empty',...
    'FontColor', [0.5 0.5 0.5]);
fig.UserData.ragStatus = ragStatusLabel;

% RAG Settings Panel
ragSettingsPanel = uipanel(fig, 'Title', 'RAG Models',...
    'Position', [790 240 390 70],...
    'BackgroundColor', [0.95 1 0.95]);

uilabel(ragSettingsPanel, 'Position', [10 20 120 20], 'Text', 'Embedding Model:');
fig.UserData.embedModelField = uidropdown(ragSettingsPanel,...
    'Position', [140 20 200 22],...
    'Items', {'Loading...'},...
    'Value', 'Loading...',...
    'ValueChangedFcn', @(dd,event) onEmbedModelChanged);

% Refresh button for embedding models
uibutton(ragSettingsPanel, 'push',...
    'Text', '↻',...
    'Position', [350 20 25 22],...
    'FontSize', 14,...
    'Tooltip', 'Refresh embedding models',...
    'ButtonPushedFcn', @(btn,event) refreshEmbeddingModels);

% uibutton(ragSettingsPanel, 'push',...
%     'Text', 'Test Embeddings',...
%     'Position', [10 20 120 30],...
%     'ButtonPushedFcn', @(btn,event) testEmbeddings);

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
    'Position', [430 35 350 140],...
    'BackgroundColor', [0.95 0.95 0.95]);

inputField = uieditfield(inputPanel, 'text',...
    'Position', [10 10 200 100],...
    'Placeholder', 'Type your message here...',...
    'FontSize', 12);

sendButton = uibutton(inputPanel, 'push',...
    'Text', 'Send',...
    'Position', [220 70 115 40],...
    'FontSize', 14,...
    'BackgroundColor', [0.3 0.6 1],...
    'FontColor', [1 1 1],...
    'ButtonPushedFcn', @(btn,event) sendMessage);

uibutton(inputPanel, 'push',...
    'Text', 'New Chat',...
    'Position', [240 10 70 20],...
    'FontSize', 12,...
    'BackgroundColor', [0.4 0.8 0.4],...
    'FontColor', [1 1 1],...
    'ButtonPushedFcn', @(btn,event) handleNewChat);

% Settings button
uibutton(fig, 'push',...
    'Text', 'Settings',...
    'Position', [1080 670 100 25],...
    'FontSize', 12,...
    'BackgroundColor', [0.8 0.8 0.8],...
    'ButtonPushedFcn', @(btn,event) openSettings(fig));

% Initialize connection
initializeConnection();

%% Callback Functions

    function initializeConnection()
        updateHistory('system', 'Initializing connection to Ollama...');
        [isConnected, availableModels, errorMsg] = testOllamaConnection();

        if isConnected && ~isempty(availableModels)
            fig.UserData.connectionStatus = 'connected';
            fig.UserData.availableModels = availableModels;
            selectedModel = selectBestModel(availableModels);
            fig.UserData.model = selectedModel;

            updateHistory('system', sprintf('Connected! Using model: %s', selectedModel));

            % Load embedding models
            refreshEmbeddingModels();

        else
            fig.UserData.connectionStatus = 'disconnected';
            updateHistory('system', sprintf('Connection failed: %s', errorMsg));
            sendButton.Enable = 'off';
        end
    end

    function refreshEmbeddingModels()
        updateHistory('system', 'Refreshing embedding models...');

        try
            % Get all available models
            testOptions = weboptions('RequestMethod', 'get', 'Timeout', 10);
            apiUrl = strrep(fig.UserData.apiUrl, '/api/generate', '/api/tags');
            response = webread(apiUrl, testOptions);

            embeddingModels = {};

            if isfield(response, 'models') && ~isempty(response.models)
                allModels = {response.models.name};

                % Filter for embedding models using multiple criteria
                for i = 1:length(allModels)
                    modelName = lower(allModels{i});

                    % Check if model name suggests it's an embedding model
                    isEmbeddingModel = contains(modelName, 'embed') || ...
                        contains(modelName, 'sentence') || ...
                        contains(modelName, 'minilm') || ...
                        contains(modelName, 'bge') || ...
                        contains(modelName, 'gte') || ...
                        contains(modelName, 'e5') || ...
                        contains(modelName, 'nomic') || ...
                        contains(modelName, 'mxbai');

                    if isEmbeddingModel
                        embeddingModels{end+1} = allModels{i};
                    end
                end

                % Test each potential embedding model
                validEmbedModels = {};
                for i = 1:length(embeddingModels)
                    if testEmbeddingModel(embeddingModels{i})
                        validEmbedModels{end+1} = embeddingModels{i};
                    end
                end

                % Add common embedding models if not found
                commonEmbedModels = {'nomic-embed-text', 'all-minilm', 'mxbai-embed-large'};
                for i = 1:length(commonEmbedModels)
                    if ~ismember(commonEmbedModels{i}, validEmbedModels)
                        validEmbedModels{end+1} = commonEmbedModels{i};
                    end
                end

                embeddingModels = validEmbedModels;
            end

            % Fallback to common models if none found
            if isempty(embeddingModels)
                embeddingModels = {'nomic-embed-text', 'all-minilm', 'mxbai-embed-large', ...
                    'sentence-transformers', 'bge-large', 'gte-large'};
            end

            % Update dropdown
            fig.UserData.availableEmbedModels = embeddingModels;
            fig.UserData.embedModelField.Items = embeddingModels;

            % Set current value
            if ismember(fig.UserData.embedModel, embeddingModels)
                fig.UserData.embedModelField.Value = fig.UserData.embedModel;
            else
                fig.UserData.embedModelField.Value = embeddingModels{1};
                fig.UserData.embedModel = embeddingModels{1};
            end

            updateHistory('system', sprintf('Found %d embedding models: %s', ...
                length(embeddingModels), strjoin(embeddingModels, ', ')));

        catch ME
            updateHistory('system', sprintf('Error loading embedding models: %s', ME.message));
            updateHistory('system', 'Using default embedding models list');

            % Fallback to default list
            defaultModels = {'nomic-embed-text', 'all-minilm', 'mxbai-embed-large'};
            fig.UserData.availableEmbedModels = defaultModels;
            fig.UserData.embedModelField.Items = defaultModels;
            fig.UserData.embedModelField.Value = defaultModels{1};
            fig.UserData.embedModel = defaultModels{1};
        end
    end

    function isValid = testEmbeddingModel(modelName)
        isValid = false;
        try
            data = struct('model', modelName, 'input', 'test');
            response = webwrite(fig.UserData.embedUrl, data, ...
                weboptions('MediaType', 'application/json',...
                'RequestMethod', 'post',...
                'Timeout', 10));

            isValid = (isfield(response, 'embeddings') || isfield(response, 'embedding')) && ...
                ~isempty(response.embeddings) || ~isempty(response.embedding);
        catch
            % Model doesn't support embeddings or isn't available
        end
    end

    function onEmbedModelChanged()
        fig.UserData.embedModel = fig.UserData.embedModelField.Value;
        updateHistory('system', sprintf('Embedding model changed to: %s', fig.UserData.embedModel));
        testEmbeddings();
    end

    function [isConnected, models, errorMsg] = testOllamaConnection()
        isConnected = false;
        models = {};
        errorMsg = '';

        try
            testOptions = weboptions('RequestMethod', 'get', 'Timeout', 10);
            apiUrl = strrep(fig.UserData.apiUrl, '/api/generate', '/api/tags');
            response = webread(apiUrl, testOptions);

            if isfield(response, 'models') && ~isempty(response.models)
                isConnected = true;
                models = {response.models.name};
                models = unique(models, 'stable');
            else
                isConnected = true;
                models = {};
            end
        catch ME
            errorMsg = ME.message;
        end
    end

    function selectedModel = selectBestModel(models)
        preferredModels = {
            'llama3.2-vision:latest';
            'llama3.2:latest';
            'llama3.1:latest';
            'llama3:latest';
            'llama2:latest';
            'mistral:latest';
            'codellama:latest'
            };

        if iscell(models)
            models = cellfun(@char, models, 'UniformOutput', false);
        end
        preferredModels = cellfun(@char, preferredModels, 'UniformOutput', false);

        % First pass: exact matches
        for i = 1:length(preferredModels)
            if ismember(preferredModels{i}, models)
                selectedModel = preferredModels{i};
                return;
            end
        end

        % Second pass: prefix matches
        for i = 1:length(preferredModels)
            baseModel = strrep(preferredModels{i}, ':latest', '');
            for j = 1:length(models)
                if startsWith(models{j}, baseModel)
                    selectedModel = models{j};
                    return;
                end
            end
        end

        % Default fallback
        if ~isempty(models)
            selectedModel = models{1};
        else
            selectedModel = 'llama3.2:latest';
        end
    end

    function testEmbeddings()
        try
            embedModel = fig.UserData.embedModel;
            data = struct('model', embedModel, 'input', 'test embedding');

            response = webwrite(fig.UserData.embedUrl, data, fig.UserData.httpOptions);

            if isfield(response, 'embeddings') && ~isempty(response.embeddings)
                updateHistory('system', sprintf('✓ Embedding model "%s" is working!', embedModel));
            elseif isfield(response, 'embedding') && ~isempty(response.embedding)
                updateHistory('system', sprintf('✓ Embedding model "%s" is working!', embedModel));
            else
                error('Invalid embedding response');
            end
        catch ME
            updateHistory('system', sprintf('✗ Embedding test failed: %s', ME.message));
            updateHistory('system', sprintf('Suggestion: Install with "ollama pull %s"', fig.UserData.embedModel));
        end
    end

    function addDocuments()
        [files, path] = uigetfile(...
            {'*.txt;*.pdf;*.docx', 'Document Files (*.txt, *.pdf, *.docx)'},...
            'MultiSelect', 'on',...
            'Select documents to add to knowledge base');

        if ~isequal(files, 0)
            if ischar(files)
                files = {files};
            end

            updateHistory('system', sprintf('Processing %d document(s)...', length(files)));

            for i = 1:length(files)
                filePath = fullfile(path, files{i});
                processDocument(filePath);
            end

            updateKnowledgeBaseDisplay();
            updateHistory('system', sprintf('Knowledge base updated: %d chunks total', length(fig.UserData.documentChunks)));
        end
    end

    function processDocument(filePath)
        try
            [~, filename, ext] = fileparts(filePath);
            textContent = extractDocumentText(filePath);

            if contains(textContent, 'Error:')
                updateHistory('system', sprintf('Failed to process %s: %s', filename, textContent));
                return;
            end

            % Use the chunkSize from UserData instead of spinner
            chunkSize = fig.UserData.chunkSize;
            chunks = splitTextIntoChunks(textContent, chunkSize);

            updateHistory('system', sprintf('Processing %s: %d chunks', filename, length(chunks)));

            for i = 1:length(chunks)
                try
                    embedding = generateEmbedding(chunks{i});

                    fig.UserData.documentChunks{end+1} = chunks{i};
                    if isempty(fig.UserData.chunkEmbeddings)
                        fig.UserData.chunkEmbeddings = embedding;
                    else
                        fig.UserData.chunkEmbeddings(end+1, :) = embedding;
                    end
                    fig.UserData.chunkMetadata{end+1} = struct(...
                        'filename', filename,...
                        'chunk_id', i,...
                        'file_path', filePath);

                catch ME
                    updateHistory('system', sprintf('Failed to embed chunk %d from %s: %s', i, filename, ME.message));
                end
            end

        catch ME
            updateHistory('system', sprintf('Error processing document %s: %s', filePath, ME.message));
        end
    end

    function chunks = splitTextIntoChunks(text, chunkSize)
        chunks = {};
        if isempty(text) || length(text) <= chunkSize
            chunks{1} = text;
            return;
        end

        sentences = regexp(text, '[.!?]+\s+', 'split');

        currentChunk = '';
        for i = 1:length(sentences)
            testChunk = [currentChunk ' ' sentences{i}];

            if length(testChunk) > chunkSize && ~isempty(currentChunk)
                chunks{end+1} = strtrim(currentChunk);
                currentChunk = sentences{i};
            else
                currentChunk = testChunk;
            end
        end

        if ~isempty(currentChunk)
            chunks{end+1} = strtrim(currentChunk);
        end
    end

    function embedding = generateEmbedding(text)
        data = struct('model', fig.UserData.embedModel, 'input', text);
        response = webwrite(fig.UserData.embedUrl, data, fig.UserData.httpOptions);

        if isfield(response, 'embeddings')
            embedding = response.embeddings(1,:);
        elseif isfield(response, 'embedding')
            embedding = response.embedding;
        else
            error('No embedding found in response');
        end
    end

    function relevantChunks = retrieveRelevantChunks(query)
        relevantChunks = {};

        if isempty(fig.UserData.documentChunks)
            return;
        end

        try
            queryEmbedding = generateEmbedding(query);

            similarities = zeros(size(fig.UserData.chunkEmbeddings, 1), 1);
            for i = 1:size(fig.UserData.chunkEmbeddings, 1)
                similarities(i) = cosineSimilarity(queryEmbedding, fig.UserData.chunkEmbeddings(i, :));
            end

            [~, sortedIndices] = sort(similarities, 'descend');
            % Use maxRetrievals from UserData instead of spinner
            maxRetrievals = min(fig.UserData.maxRetrievals, length(sortedIndices));

            % Use similarityThreshold from UserData
            threshold = fig.UserData.similarityThreshold;

            for i = 1:maxRetrievals
                idx = sortedIndices(i);
                if similarities(idx) > threshold
                    relevantChunks{end+1} = struct(...
                        'content', fig.UserData.documentChunks{idx},...
                        'metadata', fig.UserData.chunkMetadata{idx},...
                        'similarity', similarities(idx));
                end
            end

        catch ME
            updateHistory('system', sprintf('Retrieval error: %s', ME.message));
        end
    end

    function similarity = cosineSimilarity(vec1, vec2)
        dotProduct = dot(vec1, vec2);
        norm1 = norm(vec1);
        norm2 = norm(vec2);

        if norm1 == 0 || norm2 == 0
            similarity = 0;
        else
            similarity = dotProduct / (norm1 * norm2);
        end
    end

    function clearKnowledgeBase()
        fig.UserData.documentChunks = {};
        fig.UserData.chunkEmbeddings = [];
        fig.UserData.chunkMetadata = {};
        updateKnowledgeBaseDisplay();
        updateHistory('system', 'Knowledge base cleared');
    end

    function updateKnowledgeBaseDisplay()
        if isempty(fig.UserData.documentChunks)
            fig.UserData.kbList.Items = {};
            fig.UserData.ragStatus.Text = 'Knowledge Base: Empty';
        else
            docs = {};
            for i = 1:length(fig.UserData.chunkMetadata)
                filename = fig.UserData.chunkMetadata{i}.filename;
                if ~ismember(filename, docs)
                    docs{end+1} = filename;
                end
            end

            items = {};
            for i = 1:length(docs)
                chunkCount = sum(cellfun(@(x) strcmp(x.filename, docs{i}), fig.UserData.chunkMetadata));
                items{end+1} = sprintf('%s (%d chunks)', docs{i}, chunkCount);
            end

            fig.UserData.kbList.Items = items;
            fig.UserData.ragStatus.Text = sprintf('Knowledge Base: %d documents, %d chunks', ...
                length(docs), length(fig.UserData.documentChunks));
        end
    end

    function browseFiles()
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

    function sendMessage()
        if strcmp(fig.UserData.connectionStatus, 'disconnected')
            uialert(fig, 'Cannot send message: Ollama not connected', 'Connection Error');
            return;
        end

        prompt = inputField.Value;
        files = fig.UserData.currentFiles;

        if isempty(prompt) && isempty(files)
            return;
        end

        sendButton.Enable = 'off';
        busyText = uilabel(inputPanel, 'Text', 'Processing...',...
            'Position', [220 40 115 20],...
            'FontSize', 12, 'FontColor', [1 0 0],...
            'HorizontalAlignment', 'center');

        if ~isempty(prompt)
            updateHistory('user', prompt);
        end
        if ~isempty(files)
            for i = 1:length(files)
                updateHistory('system', ['Uploaded file: ' files{i}]);
            end
        end

        inputField.Value = '';
        fig.UserData.currentFiles = {};
        fig.UserData.fileList.Items = {};

        drawnow;
        processRequest(prompt, files, @() onRequestComplete(busyText));
    end

    function processRequest(prompt, files, completionCallback)
        try
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

            contextPrompt = '';
            if fig.UserData.ragToggle.Value && ~isempty(fig.UserData.documentChunks)
                relevantChunks = retrieveRelevantChunks(prompt);

                if ~isempty(relevantChunks)
                    contextPrompt = sprintf('\n\n--- RELEVANT CONTEXT FROM DOCUMENTS ---\n');
                    for i = 1:length(relevantChunks)
                        chunk = relevantChunks{i};
                        contextPrompt = sprintf('%s\nFrom %s (similarity: %.3f):\n%s\n', ...
                            contextPrompt, chunk.metadata.filename, chunk.similarity, chunk.content);
                    end
                    contextPrompt = sprintf('%s--- END CONTEXT ---\n\n', contextPrompt);

                    updateHistory('system', sprintf('Retrieved %d relevant document chunks', length(relevantChunks)));
                end
            end

            fullPrompt = [contextPrompt fullPrompt prompt];

            if ~strcmp(fig.UserData.messages(1).content, fig.UserData.systemPrompt)
                fig.UserData.messages(1).content = fig.UserData.systemPrompt;
            end

            newUserMsg = struct('role', 'user', 'content', fullPrompt);
            fig.UserData.messages(end+1) = newUserMsg;

            data = struct(...
                'model', fig.UserData.model,...
                'prompt', buildPrompt(fig.UserData.messages),...
                'stream', false,...
                'options', fig.UserData.modelOptions);

            if ~isempty(imageEncodings)
                data.images = imageEncodings;
            end

            response = webwrite(fig.UserData.apiUrl, data, fig.UserData.httpOptions);
            aiResponse = response.response;

            updateHistory('assistant', aiResponse);
            newAiMsg = struct('role', 'assistant', 'content', aiResponse);
            fig.UserData.messages(end+1) = newAiMsg;

        catch ME
            updateHistory('system', ['Error: ' ME.message]);
        end

        completionCallback();
    end

    function handleNewChat()
        fig.UserData.messages = struct('role', {'system'}, 'content', {fig.UserData.systemPrompt});
        historyBox.HTMLSource = '<html><body style="font-family: Arial; font-size: 12px; background-color: white; padding: 10px;"></body></html>';
        fig.UserData.currentFiles = {};
        fig.UserData.fileList.Items = {};
        updateHistory('system', sprintf('New chat session started with RAG %s', ...
            ternary(fig.UserData.ragToggle.Value, 'enabled', 'disabled')));
    end

    function onRequestComplete(busyText)
        sendButton.Enable = 'on';
        delete(busyText);
        drawnow;
    end

    function updateHistory(role, content)
        currentHTML = historyBox.HTMLSource;
        bodyStart = strfind(currentHTML, '<body');
        bodyEnd = strfind(currentHTML, '</body>');

        if ~isempty(bodyStart) && ~isempty(bodyEnd)
            bodyTagEnd = strfind(currentHTML(bodyStart:end), '>');
            bodyContentStart = bodyStart + bodyTagEnd(1);
            bodyContent = currentHTML(bodyContentStart:bodyEnd-1);
        else
            bodyContent = '';
        end

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

        newHTML = sprintf('<html><body style="font-family: Arial; font-size: 12px; background-color: white; padding: 10px;">%s%s</body></html>', ...
            bodyContent, newEntry);
        historyBox.HTMLSource = newHTML;

        scrollScript = '<script>window.scrollTo(0, document.body.scrollHeight);</script>';
        historyBox.HTMLSource = strrep(historyBox.HTMLSource, '</body>', [scrollScript '</body>']);
    end

    function openSettings(parentFig)
        % Enhanced settings dialog with all LLM model parameters
        settingsFig = uifigure('Name', 'LLM Settings', 'Position', [400 200 600 600]);
        movegui(settingsFig, 'center');

        % Create tab group for organized settings
        tabGroup = uitabgroup(settingsFig, 'Position', [10 10 580 580]);

        % Connection Tab
        connectionTab = uitab(tabGroup, 'Title', 'Connection');
        createConnectionSettings(connectionTab, parentFig);

        % Model Parameters Tab
        modelTab = uitab(tabGroup, 'Title', 'Model Parameters');
        createModelSettings(modelTab, parentFig);

        % RAG Settings Tab
        ragTab = uitab(tabGroup, 'Title', 'RAG Settings');
        createRAGSettings(ragTab, parentFig);

        % System Prompt Tab
        promptTab = uitab(tabGroup, 'Title', 'System Prompt');
        createPromptSettings(promptTab, parentFig);

        function createConnectionSettings(tab, parentFig)
            grid = uigridlayout(tab, [6 2]);
            grid.RowHeight = {'fit', 'fit', 'fit', 'fit', 'fit', '1x'};
            grid.ColumnWidth = [150 400];

            % API URL
            uilabel(grid, 'Text', 'API URL:', 'FontWeight', 'bold');
            apiField = uieditfield(grid, 'text', 'Value', parentFig.UserData.apiUrl);

            % Embed URL
            uilabel(grid, 'Text', 'Embed URL:', 'FontWeight', 'bold');
            embedField = uieditfield(grid, 'text', 'Value', parentFig.UserData.embedUrl);

            % Model Selection
            uilabel(grid, 'Text', 'Chat Model:', 'FontWeight', 'bold');
            % Ensure we have the correct chat models list (exclude embedding models)
            chatModels = parentFig.UserData.availableModels;
            if ~isempty(chatModels)
                % Filter out obvious embedding models from chat models list
                chatModels = filterOutEmbeddingModels(chatModels);
            end
            if isempty(chatModels)
                chatModels = {'llama3.2:latest', 'llama3.1:latest', 'mistral:latest'};
            end
            modelField = uidropdown(grid, 'Items', chatModels, ...
                'Value', parentFig.UserData.model);

            % Embedding Model
            uilabel(grid, 'Text', 'Embedding Model:', 'FontWeight', 'bold');
            % Ensure we have the correct embedding models list
            embedModels = parentFig.UserData.availableEmbedModels;
            if isempty(embedModels) || (length(embedModels) == 1 && strcmp(embedModels{1}, 'Loading...'))
                embedModels = {'nomic-embed-text', 'all-minilm', 'mxbai-embed-large'};
            end
            embedModelField = uidropdown(grid, 'Items', embedModels, ...
                'Value', parentFig.UserData.embedModel);

            % Connection Test Button
            testBtn = uibutton(grid, 'push', 'Text', 'Test Connection', ...
                'ButtonPushedFcn', @(~,~) testConnection(parentFig));
            testBtn.Layout.Column = [1 2];

            % Store references for saving
            tab.UserData.apiField = apiField;
            tab.UserData.embedField = embedField;
            tab.UserData.modelField = modelField;
            tab.UserData.embedModelField = embedModelField;
        end

        function createModelSettings(tab, parentFig)
            grid = uigridlayout(tab, [12 2]);
            grid.RowHeight = repmat({'fit'}, 1, 12);
            grid.ColumnWidth = [200 350];

            % Temperature
            uilabel(grid, 'Text', 'Temperature (0.0-2.0):', 'FontWeight', 'bold');
            tempSpinner = uispinner(grid, 'Limits', [0 2], 'Step', 0.1, ...
                'Value', parentFig.UserData.modelOptions.temperature);
            tempSpinner.ValueDisplayFormat = '%.2f';

            % Top P
            uilabel(grid, 'Text', 'Top P (0.0-1.0):', 'FontWeight', 'bold');
            topPSpinner = uispinner(grid, 'Limits', [0 1], 'Step', 0.05, ...
                'Value', parentFig.UserData.modelOptions.top_p);
            topPSpinner.ValueDisplayFormat = '%.2f';

            % Top K
            uilabel(grid, 'Text', 'Top K (1-100):', 'FontWeight', 'bold');
            topKSpinner = uispinner(grid, 'Limits', [1 100], 'Step', 1, ...
                'Value', parentFig.UserData.modelOptions.top_k);

            % Context Length
            uilabel(grid, 'Text', 'Context Length (512-32768):', 'FontWeight', 'bold');
            ctxSpinner = uispinner(grid, 'Limits', [512 32768], 'Step', 256, ...
                'Value', parentFig.UserData.modelOptions.num_ctx);

            % Max Tokens to Generate
            uilabel(grid, 'Text', 'Max Tokens (-1=unlimited):', 'FontWeight', 'bold');
            predictSpinner = uispinner(grid, 'Limits', [-1 16384], 'Step', 64, ...
                'Value', parentFig.UserData.modelOptions.num_predict);

            % Seed
            uilabel(grid, 'Text', 'Seed (0=random):', 'FontWeight', 'bold');
            seedSpinner = uispinner(grid, 'Limits', [0 2147483647], 'Step', 1, ...
                'Value', parentFig.UserData.modelOptions.seed);

            % Repeat Penalty
            uilabel(grid, 'Text', 'Repeat Penalty (0.0-2.0):', 'FontWeight', 'bold');
            repeatSpinner = uispinner(grid, 'Limits', [0 2], 'Step', 0.05, ...
                'Value', getModelOptionValue(parentFig, 'repeat_penalty', 1.1));
            repeatSpinner.ValueDisplayFormat = '%.2f';

            % Presence Penalty
            uilabel(grid, 'Text', 'Presence Penalty (-2.0-2.0):', 'FontWeight', 'bold');
            presenceSpinner = uispinner(grid, 'Limits', [-2 2], 'Step', 0.1, ...
                'Value', getModelOptionValue(parentFig, 'presence_penalty', 0.0));
            presenceSpinner.ValueDisplayFormat = '%.2f';

            % Frequency Penalty
            uilabel(grid, 'Text', 'Frequency Penalty (-2.0-2.0):', 'FontWeight', 'bold');
            freqSpinner = uispinner(grid, 'Limits', [-2 2], 'Step', 0.1, ...
                'Value', getModelOptionValue(parentFig, 'frequency_penalty', 0.0));
            freqSpinner.ValueDisplayFormat = '%.2f';

            % TFS Z
            uilabel(grid, 'Text', 'TFS Z (0.0-1.0):', 'FontWeight', 'bold');
            tfsSpinner = uispinner(grid, 'Limits', [0 1], 'Step', 0.05, ...
                'Value', getModelOptionValue(parentFig, 'tfs_z', 1.0));
            tfsSpinner.ValueDisplayFormat = '%.2f';

            % Mirostat
            uilabel(grid, 'Text', 'Mirostat (0=off, 1=v1, 2=v2):', 'FontWeight', 'bold');
            mirostatSpinner = uispinner(grid, 'Limits', [0 2], 'Step', 1, ...
                'Value', getModelOptionValue(parentFig, 'mirostat', 0));

            % Reset to Defaults Button
            resetBtn = uibutton(grid, 'push', 'Text', 'Reset to Defaults', ...
                'ButtonPushedFcn', @(~,~) resetModelDefaults());
            resetBtn.Layout.Column = [1 2];

            % Store references for saving
            tab.UserData.tempSpinner = tempSpinner;
            tab.UserData.topPSpinner = topPSpinner;
            tab.UserData.topKSpinner = topKSpinner;
            tab.UserData.ctxSpinner = ctxSpinner;
            tab.UserData.predictSpinner = predictSpinner;
            tab.UserData.seedSpinner = seedSpinner;
            tab.UserData.repeatSpinner = repeatSpinner;
            tab.UserData.presenceSpinner = presenceSpinner;
            tab.UserData.freqSpinner = freqSpinner;
            tab.UserData.tfsSpinner = tfsSpinner;
            tab.UserData.mirostatSpinner = mirostatSpinner;

            function resetModelDefaults()
                tempSpinner.Value = 0.7;
                topPSpinner.Value = 0.9;
                topKSpinner.Value = 40;
                ctxSpinner.Value = 2048;
                predictSpinner.Value = 256;
                seedSpinner.Value = 0;
                repeatSpinner.Value = 1.1;
                presenceSpinner.Value = 0.0;
                freqSpinner.Value = 0.0;
                tfsSpinner.Value = 1.0;
                mirostatSpinner.Value = 0;
            end
        end

        function createRAGSettings(tab, parentFig)
            grid = uigridlayout(tab, [5 2]); % Reduced to 5 rows
            grid.RowHeight = repmat({'fit'}, 1, 5);
            grid.ColumnWidth = [200 350];

            % Max Retrievals
            uilabel(grid, 'Text', 'Max Retrievals (1-10):', 'FontWeight', 'bold');
            maxRetrSpinner = uispinner(grid, 'Limits', [1 10], 'Step', 1, ...
                'Value', parentFig.UserData.maxRetrievals);

            % Chunk Size - use the stored value from UserData
            uilabel(grid, 'Text', 'Chunk Size (100-2000):', 'FontWeight', 'bold');
            chunkSpinner = uispinner(grid, 'Limits', [100 2000], 'Step', 50, ...
                'Value', parentFig.UserData.chunkSize);

            % Similarity Threshold
            uilabel(grid, 'Text', 'Similarity Threshold (0.0-1.0):', 'FontWeight', 'bold');
            simThreshSpinner = uispinner(grid, 'Limits', [0 1], 'Step', 0.05, ...
                'Value', parentFig.UserData.similarityThreshold);
            simThreshSpinner.ValueDisplayFormat = '%.2f';

            % Chunk Overlap
            uilabel(grid, 'Text', 'Chunk Overlap (0-500):', 'FontWeight', 'bold');
            overlapSpinner = uispinner(grid, 'Limits', [0 500], 'Step', 25, ...
                'Value', getModelOptionValue(parentFig, 'chunk_overlap', 50));

            % Context Window for RAG
            uilabel(grid, 'Text', 'RAG Context Window (512-8192):', 'FontWeight', 'bold');
            ragCtxSpinner = uispinner(grid, 'Limits', [512 8192], 'Step', 256, ...
                'Value', getModelOptionValue(parentFig, 'rag_context_window', 2048));

            % Store references for saving
            tab.UserData.maxRetrSpinner = maxRetrSpinner;
            tab.UserData.chunkSpinner = chunkSpinner;
            tab.UserData.simThreshSpinner = simThreshSpinner;
            tab.UserData.overlapSpinner = overlapSpinner;
            tab.UserData.ragCtxSpinner = ragCtxSpinner;
        end

        function createPromptSettings(tab, parentFig)
            % Reserve space at the bottom (reduced from 60px to 45px) for Save/Cancel
            contentPanel = uipanel(tab, ...
                'Units', 'pixels', ...
                'Position', [0 45 tab.Position(3) tab.Position(4)-45], ...
                'BorderType', 'none');
            % Use normalized units so resizing works
            contentPanel.Units = 'normalized';

            % Grid inside the content area
            grid = uigridlayout(contentPanel, [3 1]);
            grid.RowHeight = {'fit', '1x', 100}; % Reduced template panel height from 150 to 120
            grid.RowSpacing = 8;
            grid.Padding = [10 10 10 5]; % Reduced bottom padding from 10 to 5

            % Label
            uilabel(grid, ...
                'Text', 'System Prompt:', ...
                'FontWeight', 'bold', ...
                'FontSize', 14);

            % Text area
            sysField = uitextarea(grid, ...
                'Value', parentFig.UserData.systemPrompt, ...
                'FontSize', 14);

            % --- Quick Templates Panel (Compact Style) ---
            templatePanel = uipanel(grid, ...
                'Title', 'Quick Templates', ...
                'FontSize', 14, ... % Smaller title text
                'FontWeight', 'normal', ... % Not bold
                'BorderType', 'line'); % Thin border (set 'none' to remove)

            templateGrid = uigridlayout(templatePanel, [2 3]);
            templateGrid.RowSpacing = 5;
            templateGrid.ColumnSpacing = 5;
            templateGrid.Padding = [3 3 3 3]; % Reduced padding inside panel
            templateGrid.RowHeight = {28, 28}; % Compact row heights
            templateGrid.ColumnWidth = {'1x','1x','1x'};

            % Buttons with smaller font
            btnStyle = {'FontSize', 12};

            uibutton(templateGrid, 'push', ...
                'Text', 'Default Assistant', btnStyle{:}, ...
                'ButtonPushedFcn', @(~,~) setTemplate('You are a helpful assistant with access to uploaded documents.'));

            uibutton(templateGrid, 'push', ...
                'Text', 'Code Expert', btnStyle{:}, ...
                'ButtonPushedFcn', @(~,~) setTemplate('You are an expert programmer and code reviewer. Provide detailed, accurate code assistance.'));

            uibutton(templateGrid, 'push', ...
                'Text', 'Research Assistant', btnStyle{:}, ...
                'ButtonPushedFcn', @(~,~) setTemplate('You are a research assistant. Analyze documents thoroughly and provide evidence-based responses.'));

            uibutton(templateGrid, 'push', ...
                'Text', 'Technical Writer', btnStyle{:}, ...
                'ButtonPushedFcn', @(~,~) setTemplate('You are a technical writer. Create clear, well-structured documentation and explanations.'));

            uibutton(templateGrid, 'push', ...
                'Text', 'Data Analyst', btnStyle{:}, ...
                'ButtonPushedFcn', @(~,~) setTemplate('You are a data analyst. Focus on extracting insights, patterns, and actionable information from data and documents.'));

            uibutton(templateGrid, 'push', ...
                'Text', 'Custom', btnStyle{:}, ...
                'ButtonPushedFcn', @(~,~) customTemplate());

            % Store handle
            tab.UserData.sysField = sysField;

            % Helper functions
            function setTemplate(template)
                sysField.Value = template;
            end

            function customTemplate()
                currentValue = sysField.Value;
                if isstring(currentValue), currentValue = char(currentValue); end
                if ischar(currentValue), currentValue = {currentValue}; end
                if ~iscell(currentValue), currentValue = {''}; end

                answer = inputdlg('Enter custom system prompt:', ...
                    'Custom Template', [5 50], currentValue);
                if ~isempty(answer)
                    sysField.Value = answer{1};
                end
            end
        end

        % Save All Settings Button
        saveBtn = uibutton(settingsFig, 'push', 'Text', 'Save All Settings', ...
            'Position', [220 13 100 30], 'FontSize', 12, 'FontWeight', 'bold', ...
            'BackgroundColor', [0.2 0.7 0.2], 'FontColor', [1 1 1], ...
            'ButtonPushedFcn', @(~,~) saveAllSettings());

        % Cancel Button
        cancelBtn = uibutton(settingsFig, 'push', 'Text', 'Cancel', ...
            'Position', [360 13 100 30], 'FontSize', 12, ...
            'ButtonPushedFcn', @(~,~) close(settingsFig));

                % Cancel Button
        helpBtn = uibutton(settingsFig, 'push', 'Text', 'Help', ...
            'Position', [75 13 100 30], 'FontSize', 12, ...
            'ButtonPushedFcn', @(~,~) openLLMHelpWindow);

        function saveAllSettings()
            try
                tabs = tabGroup.Children;

                % Save Connection Settings
                connTab = findTabByTitle(tabs, 'Connection');
                if ~isempty(connTab)
                    parentFig.UserData.apiUrl = connTab.UserData.apiField.Value;
                    parentFig.UserData.embedUrl = connTab.UserData.embedField.Value;
                    parentFig.UserData.model = connTab.UserData.modelField.Value;
                    parentFig.UserData.embedModel = connTab.UserData.embedModelField.Value;
                end

                % Save Model Parameters
                modelTab = findTabByTitle(tabs, 'Model Parameters');
                if ~isempty(modelTab)
                    parentFig.UserData.modelOptions.temperature = modelTab.UserData.tempSpinner.Value;
                    parentFig.UserData.modelOptions.top_p = modelTab.UserData.topPSpinner.Value;
                    parentFig.UserData.modelOptions.top_k = modelTab.UserData.topKSpinner.Value;
                    parentFig.UserData.modelOptions.num_ctx = modelTab.UserData.ctxSpinner.Value;
                    parentFig.UserData.modelOptions.num_predict = modelTab.UserData.predictSpinner.Value;
                    parentFig.UserData.modelOptions.seed = modelTab.UserData.seedSpinner.Value;
                    parentFig.UserData.modelOptions.repeat_penalty = modelTab.UserData.repeatSpinner.Value;
                    parentFig.UserData.modelOptions.presence_penalty = modelTab.UserData.presenceSpinner.Value;
                    parentFig.UserData.modelOptions.frequency_penalty = modelTab.UserData.freqSpinner.Value;
                    parentFig.UserData.modelOptions.tfs_z = modelTab.UserData.tfsSpinner.Value;
                    parentFig.UserData.modelOptions.mirostat = modelTab.UserData.mirostatSpinner.Value;
                end

                % Save RAG Settings
                ragTab = findTabByTitle(tabs, 'RAG Settings');
                if ~isempty(ragTab)
                    parentFig.UserData.maxRetrievals = ragTab.UserData.maxRetrSpinner.Value;
                    parentFig.UserData.chunkSize = ragTab.UserData.chunkSpinner.Value;
                    parentFig.UserData.similarityThreshold = ragTab.UserData.simThreshSpinner.Value;
                    parentFig.UserData.modelOptions.chunk_overlap = ragTab.UserData.overlapSpinner.Value;
                    parentFig.UserData.modelOptions.rag_context_window = ragTab.UserData.ragCtxSpinner.Value;
                end

                % Save System Prompt
                promptTab = findTabByTitle(tabs, 'System Prompt');
                if ~isempty(promptTab)
                    parentFig.UserData.systemPrompt = promptTab.UserData.sysField.Value;
                end

                % Update UI elements that reference these settings
                if isfield(parentFig.UserData, 'embedModelField')
                    parentFig.UserData.embedModelField.Value = parentFig.UserData.embedModel;
                end

                % Show success message
                uialert(settingsFig, 'All settings saved successfully!', 'Settings Saved', 'Icon', 'success');

                % Log the changes
                updateHistory = @(role, msg) fprintf('[%s] %s: %s\n', datestr(now, 'HH:MM:SS'), upper(role), msg);
                updateHistory('system', 'Settings updated successfully');
                updateHistory('system', sprintf('Temperature: %.2f, Top-P: %.2f, Top-K: %d', ...
                    parentFig.UserData.modelOptions.temperature, ...
                    parentFig.UserData.modelOptions.top_p, ...
                    parentFig.UserData.modelOptions.top_k));

                % Close settings window
                close(settingsFig);

            catch ME
                uialert(settingsFig, sprintf('Error saving settings: %s', ME.message), ...
                    'Save Error', 'Icon', 'error');
            end
        end
        function testConnection(parentFig)
            try
                % Test main API connection
                testOptions = weboptions('RequestMethod', 'get', 'Timeout', 5);
                apiUrl = strrep(parentFig.UserData.apiUrl, '/api/generate', '/api/tags');
                response = webread(apiUrl, testOptions);

                if isfield(response, 'models')
                    uialert(settingsFig, sprintf('✓ Connection successful! Found %d models.', ...
                        length(response.models)), 'Connection Test', 'Icon', 'success');
                else
                    uialert(settingsFig, '⚠ Connected but no models found.', ...
                        'Connection Test', 'Icon', 'warning');
                end
            catch ME
                uialert(settingsFig, sprintf('✗ Connection failed: %s', ME.message), ...
                    'Connection Test', 'Icon', 'error');
            end
        end
    end

    function value = getModelOptionValue(parentFig, fieldName, defaultValue)
        if isfield(parentFig.UserData.modelOptions, fieldName)
            value = parentFig.UserData.modelOptions.(fieldName);
        else
            value = defaultValue;
        end
    end

    function tab = findTabByTitle(tabs, title)
        tab = [];
        for i = 1:length(tabs)
            if strcmp(tabs(i).Title, title)
                tab = tabs(i);
                break;
            end
        end
    end

    function filteredModels = filterOutEmbeddingModels(models)
        % Filter out models that are likely embedding models
        filteredModels = {};

        for i = 1:length(models)
            modelName = lower(models{i});

            % Skip if model name suggests it's an embedding model
            isEmbeddingModel = contains(modelName, 'embed') || ...
                contains(modelName, 'sentence') || ...
                contains(modelName, 'minilm') || ...
                contains(modelName, 'bge') || ...
                contains(modelName, 'gte') || ...
                contains(modelName, 'e5') || ...
                contains(modelName, 'nomic-embed') || ...
                contains(modelName, 'mxbai-embed');

            if ~isEmbeddingModel
                filteredModels{end+1} = models{i};
            end
        end

        % If we filtered out everything, keep the original list
        if isempty(filteredModels)
            filteredModels = models;
        end
    end

end

%% Helper Functions

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

function result = ternary(condition, trueValue, falseValue)
if condition
    result = trueValue;
else
    result = falseValue;
end
end

function openLLMHelpWindow()
    % Create Help Window for LLM Settings
    helpFig = uifigure('Name', 'LLM Settings Help Guide', ...
        'Position', [150 200 800 700]);
    movegui(helpFig, 'center');

    % Create Scrollable Panel
    scrollPanel = uipanel(helpFig, ...
        'Position', [0 0 800 700], ...
        'Scrollable', 'off');

    % Build comprehensive HTML content
    helpText = sprintf([...
        '<html><div style="font-family:Arial; padding:20px; line-height:1.6; max-width:760px;">',...
        '<h1 style="color:#2c3e50; border-bottom:3px solid #3498db; padding-bottom:10px;">LLM Settings Help Guide</h1>',...
        '<p style="font-size:16px; color:#34495e;">Welcome to the comprehensive help guide for <b>LLM Settings</b>! This guide covers all parameters across the four main settings tabs.</p>',...
        '<div style="background:#ecf0f1; padding:15px; border-radius:8px; margin:15px 0;">',...
        '<h3 style="margin:0; color:#2980b9;">📚 Quick Navigation</h3>',...
        '<p style="margin:5px 0;"><a href="#connection" style="text-decoration:none; color:#3498db;">Connection Settings</a> | ',...
        '<a href="#model" style="text-decoration:none; color:#3498db;">Model Parameters</a> | ',...
        '<a href="#rag" style="text-decoration:none; color:#3498db;">RAG Settings</a> | ',...
        '<a href="#prompt" style="text-decoration:none; color:#3498db;">System Prompt</a></p>',...
        '</div>',...
        '<hr style="border:1px solid #bdc3c7; margin:25px 0;">',...
        '',...
        '<h2 id="connection" style="color:#2980b9; margin-top:30px;">🔌 1. Connection Settings</h2>',...
        '<div style="background:#f8f9fa; padding:15px; border-left:4px solid #3498db; margin:10px 0;">',...
        '<h3 style="color:#2c3e50;">API URL</h3>',...
        '<ul style="margin:10px 0;">',...
        '<li><b>Purpose:</b> Main endpoint for chat completions and model communication</li>',...
        '<li><b>Default:</b> <code style="background:#e8e8e8; padding:2px 6px;">http://localhost:11434/api/generate</code></li>',...
        '<li><b>When to change:</b> Using remote server, different port, or custom deployment</li>',...
        '<li><b>Format:</b> <code>http://[host]:[port]/api/generate</code></li>',...
        '</ul>',...
        '</div>',...
        '',...
        '<div style="background:#f8f9fa; padding:15px; border-left:4px solid #3498db; margin:10px 0;">',...
        '<h3 style="color:#2c3e50;">Embed URL</h3>',...
        '<ul style="margin:10px 0;">',...
        '<li><b>Purpose:</b> Endpoint for text embedding generation (RAG functionality)</li>',...
        '<li><b>Default:</b> <code style="background:#e8e8e8; padding:2px 6px;">http://localhost:11434/api/embeddings</code></li>',...
        '<li><b>Usage:</b> Converts text to numerical vectors for similarity search</li>',...
        '</ul>',...
        '</div>',...
        '',...
        '<div style="background:#f8f9fa; padding:15px; border-left:4px solid #3498db; margin:10px 0;">',...
        '<h3 style="color:#2c3e50;">Chat Model Selection</h3>',...
        '<ul style="margin:10px 0;">',...
        '<li><b>Purpose:</b> Choose the language model for conversations</li>',...
        '<li><b>Examples:</b> <code>llama3.2:latest</code>, <code>mistral:latest</code>, <code>codellama:7b</code></li>',...
        '<li><b>Considerations:</b> Larger models = better quality but slower responses</li>',...
        '</ul>',...
        '</div>',...
        '',...
        '<div style="background:#f8f9fa; padding:15px; border-left:4px solid #3498db; margin:10px 0;">',...
        '<h3 style="color:#2c3e50;">Embedding Model</h3>',...
        '<ul style="margin:10px 0;">',...
        '<li><b>Purpose:</b> Model used for document embedding in RAG</li>',...
        '<li><b>Popular choices:</b> <code>nomic-embed-text</code>, <code>all-minilm</code>, <code>mxbai-embed-large</code></li>',...
        '<li><b>Note:</b> Must be compatible with your embedding endpoint</li>',...
        '</ul>',...
        '</div>',...
        '',...
        '<hr style="border:1px solid #bdc3c7; margin:25px 0;">',...
        '',...
        '<h2 id="model" style="color:#2980b9; margin-top:30px;">⚙️ 2. Model Parameters</h2>',...
        '<p style="color:#34495e; font-style:italic;">These parameters control how the AI generates responses. Adjust them to fine-tune behavior for your specific use case.</p>',...
        '',...
        '<div style="background:#fff3cd; padding:15px; border-left:4px solid #ffc107; margin:15px 0;">',...
        '<h3 style="color:#856404; margin-top:0;">🌡️ Temperature (0.0 - 2.0)</h3>',...
        '<ul style="margin:10px 0; color:#856404;">',...
        '<li><b>Controls:</b> Randomness and creativity in responses</li>',...
        '<li><b>Low (0.1-0.3):</b> Deterministic, focused, consistent answers</li>',...
        '<li><b>Medium (0.7-0.9):</b> Balanced creativity and coherence</li>',...
        '<li><b>High (1.5-2.0):</b> Very creative but potentially incoherent</li>',...
        '<li><b>Default:</b> 0.7 (good balance for most tasks)</li>',...
        '</ul>',...
        '</div>',...
        '',...
        '<div style="background:#d1ecf1; padding:15px; border-left:4px solid #17a2b8; margin:15px 0;">',...
        '<h3 style="color:#0c5460; margin-top:0;">🎯 Top P - Nucleus Sampling (0.0 - 1.0)</h3>',...
        '<ul style="margin:10px 0; color:#0c5460;">',...
        '<li><b>Controls:</b> Diversity by limiting token probability mass</li>',...
        '<li><b>Low (0.1-0.3):</b> Only most likely words considered</li>',...
        '<li><b>High (0.8-1.0):</b> Wider vocabulary selection allowed</li>',...
        '<li><b>Tip:</b> Use with Temperature for fine control</li>',...
        '<li><b>Default:</b> 0.9</li>',...
        '</ul>',...
        '</div>',...
        '',...
        '<div style="background:#d4edda; padding:15px; border-left:4px solid #28a745; margin:15px 0;">',...
        '<h3 style="color:#155724; margin-top:0;">🔝 Top K (1 - 100)</h3>',...
        '<ul style="margin:10px 0; color:#155724;">',...
        '<li><b>Controls:</b> Limits selection to top K most probable tokens</li>',...
        '<li><b>Low (10-20):</b> More focused, predictable responses</li>',...
        '<li><b>High (50-100):</b> More varied vocabulary usage</li>',...
        '<li><b>Interaction:</b> Works together with Top P</li>',...
        '<li><b>Default:</b> 40</li>',...
        '</ul>',...
        '</div>',...
        '',...
        '<div style="background:#f8d7da; padding:15px; border-left:4px solid #dc3545; margin:15px 0;">',...
        '<h3 style="color:#721c24; margin-top:0;">🧠 Context Length (512 - 32768)</h3>',...
        '<ul style="margin:10px 0; color:#721c24;">',...
        '<li><b>Controls:</b> How much conversation history the model remembers</li>',...
        '<li><b>Small (512-1024):</b> Fast but limited memory</li>',...
        '<li><b>Large (8192-32768):</b> Long conversations but slower</li>',...
        '<li><b>Trade-off:</b> Memory vs. processing speed</li>',...
        '<li><b>Default:</b> 2048 (good for most conversations)</li>',...
        '</ul>',...
        '</div>',...
        '',...
        '<div style="background:#e2e3e5; padding:15px; border-left:4px solid #6c757d; margin:15px 0;">',...
        '<h3 style="color:#495057; margin-top:0;">📝 Max Tokens (-1 or 1-4096)</h3>',...
        '<ul style="margin:10px 0; color:#495057;">',...
        '<li><b>Controls:</b> Maximum length of generated responses</li>',...
        '<li><b>-1:</b> Unlimited (use with caution)</li>',...
        '<li><b>Small (64-256):</b> Concise responses</li>',...
        '<li><b>Large (512-4096):</b> Detailed explanations</li>',...
        '<li><b>Default:</b> 256</li>',...
        '</ul>',...
        '</div>',...
        '',...
        '<div style="background:#f0f8ff; padding:15px; border-left:4px solid #007bff; margin:15px 0;">',...
        '<h3 style="color:#004085; margin-top:0;">🎲 Advanced Parameters</h3>',...
        '<ul style="margin:10px 0; color:#004085;">',...
        '<li><b>Seed (0 = random):</b> Set for reproducible results</li>',...
        '<li><b>Repeat Penalty (0.0-2.0):</b> Reduces repetitive text (default: 1.1)</li>',...
        '<li><b>Presence Penalty (-2.0 to 2.0):</b> Encourages topic diversity</li>',...
        '<li><b>Frequency Penalty (-2.0 to 2.0):</b> Reduces word repetition</li>',...
        '<li><b>TFS Z (0.0-1.0):</b> Tail-free sampling parameter</li>',...
        '<li><b>Mirostat (0/1/2):</b> Alternative sampling method</li>',...
        '</ul>',...
        '</div>',...
        '',...
        '<hr style="border:1px solid #bdc3c7; margin:25px 0;">',...
        '',...
        '<h2 id="rag" style="color:#2980b9; margin-top:30px;">📚 3. RAG Settings (Retrieval-Augmented Generation)</h2>',...
        '<p style="color:#34495e; font-style:italic;">Configure how the system searches and uses your uploaded documents.</p>',...
        '',...
        '<div style="background:#e8f5e8; padding:15px; border-left:4px solid #4caf50; margin:15px 0;">',...
        '<h3 style="color:#2e7d2e; margin-top:0;">🔍 Max Retrievals (1 - 10)</h3>',...
        '<ul style="margin:10px 0; color:#2e7d2e;">',...
        '<li><b>Controls:</b> How many document chunks to retrieve for each query</li>',...
        '<li><b>Low (1-3):</b> Fast but might miss relevant information</li>',...
        '<li><b>High (7-10):</b> More comprehensive but slower responses</li>',...
        '<li><b>Recommendation:</b> Start with 3-5 for balanced performance</li>',...
        '</ul>',...
        '</div>',...
        '',...
        '<div style="background:#fff2e6; padding:15px; border-left:4px solid #ff9800; margin:15px 0;">',...
        '<h3 style="color:#cc6600; margin-top:0;">📄 Chunk Size (100 - 2000)</h3>',...
        '<ul style="margin:10px 0; color:#cc6600;">',...
        '<li><b>Controls:</b> Size of document pieces for processing</li>',...
        '<li><b>Small (100-300):</b> Precise but may lose context</li>',...
        '<li><b>Large (1000-2000):</b> Better context but less precise</li>',...
        '<li><b>Sweet spot:</b> 400-800 characters for most documents</li>',...
        '</ul>',...
        '</div>',...
        '',...
        '<div style="background:#f3e5f5; padding:15px; border-left:4px solid #9c27b0; margin:15px 0;">',...
        '<h3 style="color:#6a1b9a; margin-top:0;">🎯 Similarity Threshold (0.0 - 1.0)</h3>',...
        '<ul style="margin:10px 0; color:#6a1b9a;">',...
        '<li><b>Controls:</b> Minimum similarity score for relevant chunks</li>',...
        '<li><b>Low (0.1-0.4):</b> Include loosely related content</li>',...
        '<li><b>High (0.7-0.9):</b> Only highly relevant matches</li>',...
        '<li><b>Recommendation:</b> 0.5-0.7 for most use cases</li>',...
        '</ul>',...
        '</div>',...
        '',...
        '<div style="background:#e3f2fd; padding:15px; border-left:4px solid #2196f3; margin:15px 0;">',...
        '<h3 style="color:#1565c0; margin-top:0;">🔄 Additional RAG Parameters</h3>',...
        '<ul style="margin:10px 0; color:#1565c0;">',...
        '<li><b>Chunk Overlap (0-500):</b> Character overlap between chunks (default: 50)</li>',...
        '<li><b>RAG Context Window (512-8192):</b> Context size for RAG queries (default: 2048)</li>',...
        '</ul>',...
        '</div>',...
        '',...
        '<hr style="border:1px solid #bdc3c7; margin:25px 0;">',...
        '',...
        '<h2 id="prompt" style="color:#2980b9; margin-top:30px;">💬 4. System Prompt Settings</h2>',...
        '<p style="color:#34495e;">The system prompt sets the AI''s personality, expertise, and behavior guidelines.</p>',...
        '',...
        '<div style="background:#f9f9f9; padding:15px; border-left:4px solid #6c757d; margin:15px 0;">',...
        '<h3 style="color:#495057; margin-top:0;">📝 System Prompt</h3>',...
        '<ul style="margin:10px 0; color:#495057;">',...
        '<li><b>Purpose:</b> Defines the AI''s role and behavior</li>',...
        '<li><b>Best practices:</b> Be specific about desired expertise and tone</li>',...
        '<li><b>Length:</b> Usually 1-3 sentences for clarity</li>',...
        '</ul>',...
        '</div>',...
        '',...
        '<div style="background:#e8f4fd; padding:15px; border-left:4px solid #0d6efd; margin:15px 0;">',...
        '<h3 style="color:#084298; margin-top:0;">🚀 Quick Templates</h3>',...
        '<ul style="margin:10px 0; color:#084298;">',...
        '<li><b>Default Assistant:</b> General helpful AI assistant</li>',...
        '<li><b>Code Expert:</b> Specialized for programming tasks</li>',...
        '<li><b>Research Assistant:</b> Focused on document analysis</li>',...
        '<li><b>Technical Writer:</b> For documentation and explanations</li>',...
        '<li><b>Data Analyst:</b> Extract insights from data and documents</li>',...
        '<li><b>Custom:</b> Create your own specialized prompt</li>',...
        '</ul>',...
        '</div>',...
        '',...
        '<hr style="border:1px solid #bdc3c7; margin:25px 0;">',...
        '',...
        '<h2 style="color:#27ae60; margin-top:30px;">💡 Best Practices & Tips</h2>',...
        '',...
        '<div style="background:#d5f4e6; padding:20px; border-radius:8px; margin:15px 0;">',...
        '<h3 style="color:#196f3d; margin-top:0;">🎯 For Different Use Cases:</h3>',...
        '<table style="width:100%%; border-collapse:collapse; margin:10px 0; color:#196f3d;">',...
        '<tr style="background:#a9dfbf;"><th style="padding:8px; border:1px solid #27ae60;">Use Case</th><th style="padding:8px; border:1px solid #27ae60;">Temperature</th><th style="padding:8px; border:1px solid #27ae60;">Top P</th><th style="padding:8px; border:1px solid #27ae60;">Max Tokens</th></tr>',...
        '<tr><td style="padding:8px; border:1px solid #27ae60;"><b>Factual Q&amp;A</b></td><td style="padding:8px; border:1px solid #27ae60;">0.1-0.3</td><td style="padding:8px; border:1px solid #27ae60;">0.7</td><td style="padding:8px; border:1px solid #27ae60;">256</td></tr>',...
        '<tr><td style="padding:8px; border:1px solid #27ae60;"><b>Creative Writing</b></td><td style="padding:8px; border:1px solid #27ae60;">0.8-1.2</td><td style="padding:8px; border:1px solid #27ae60;">0.9</td><td style="padding:8px; border:1px solid #27ae60;">1024+</td></tr>',...
        '<tr><td style="padding:8px; border:1px solid #27ae60;"><b>Code Generation</b></td><td style="padding:8px; border:1px solid #27ae60;">0.2-0.5</td><td style="padding:8px; border:1px solid #27ae60;">0.8</td><td style="padding:8px; border:1px solid #27ae60;">512-1024</td></tr>',...
        '<tr><td style="padding:8px; border:1px solid #27ae60;"><b>Document Analysis</b></td><td style="padding:8px; border:1px solid #27ae60;">0.3-0.6</td><td style="padding:8px; border:1px solid #27ae60;">0.85</td><td style="padding:8px; border:1px solid #27ae60;">512-1024</td></tr>',...
        '</table>',...
        '</div>',...
        '',...
        '<div style="background:#fdf2e9; padding:15px; border-left:4px solid #e67e22; margin:15px 0;">',...
        '<h3 style="color:#a04000; margin-top:0;">⚠️ Common Issues & Solutions</h3>',...
        '<ul style="margin:10px 0; color:#a04000;">',...
        '<li><b>Slow responses:</b> Reduce context length and max tokens</li>',...
        '<li><b>Repetitive text:</b> Increase repeat penalty (1.1-1.3)</li>',...
        '<li><b>Incoherent responses:</b> Lower temperature and top_p</li>',...
        '<li><b>RAG not finding docs:</b> Lower similarity threshold</li>',...
        '<li><b>Connection errors:</b> Check API URL and model availability</li>',...
        '</ul>',...
        '</div>',...
        '',...
        '<div style="background:#ebf3fd; padding:15px; border-left:4px solid #3498db; margin:15px 0;">',...
        '<h3 style="color:#2471a3; margin-top:0;">💾 Saving Settings</h3>',...
        '<ul style="margin:10px 0; color:#2471a3;">',...
        '<li>Click <b>"Save All Settings"</b> to apply all changes across tabs</li>',...
        '<li>Use <b>"Test Connection"</b> to verify API connectivity</li>',...
        '<li>Settings are applied immediately after saving</li>',...
        '<li>Use <b>"Reset to Defaults"</b> in Model Parameters if needed</li>',...
        '</ul>',...
        '</div>',...
        '',...
        '<hr style="border:1px solid #bdc3c7; margin:25px 0;">',...
        '',...
        '<div style="text-align:center; background:#2c3e50; color:white; padding:20px; border-radius:8px; margin-top:30px;">',...
        '<h3 style="margin:0 0 10px 0;">🚀 Ready to optimize your LLM experience?</h3>',...
        '<p style="margin:0; font-size:14px;">Experiment with different settings to find what works best for your specific use case!</p>',...
        '</div>',...
        '<p style="margin:0; font-size:14px;">Contact Us: ahmad.mehri@yahoo.com   @rockbench </p>',...
        '</div></html>']);

    % Create HTML component
    helpHtml = uihtml(scrollPanel, ...
        'Position', [10 10 780 680], ...
        'HTMLSource', helpText);

    % Add smooth scrolling JavaScript (properly escaped)
    jsCode = ['<script>', ...
              'window.scrollTo(0, 0);', ...
              'document.querySelectorAll(''a[href^="#"]'').forEach(anchor => {', ...
              '    anchor.addEventListener("click", function (e) {', ...
              '        e.preventDefault();', ...
              '        const target = document.querySelector(this.getAttribute("href"));', ...
              '        if (target) {', ...
              '            target.scrollIntoView({behavior: "smooth", block: "start"});', ...
              '        }', ...
              '    });', ...
              '});', ...
              '</script>'];
    
    helpHtml.HTMLSource = [helpText, jsCode];

    % Add close button
    closeBtn = uibutton(helpFig, 'push', 'Text', 'Close', ...
        'Position', [360 20 80 30], 'FontSize', 12, ...
        'ButtonPushedFcn', @(~,~) close(helpFig));
end