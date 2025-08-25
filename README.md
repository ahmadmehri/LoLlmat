Matlab Ollama LLMs

**LoLlama: Local LLM Communicator - Your Gateway to Local Open-Source AI Models**

<img width="1024" height="588" alt="ChatGPT Image Aug 25, 2025, 04_23_45 PM" src="https://github.com/user-attachments/assets/fd8b18a2-9a76-4435-8c7f-fd482069f0ec" />

Local Ollama Comunication App for windows

Welcome to the Local Ollama Chat help page! Here, you'll find explanations for all adjustable parameters in the settings menu.

![image](https://github.com/user-attachments/assets/c672101a-c541-42c6-994a-0b6aa7609889)

<img width="511" height="443" alt="image" src="https://github.com/user-attachments/assets/ac6e58d6-86ed-4b56-84f3-6eaf74955be5" />

**Help Guide for Local Ollama Chat Settings**

![image](https://github.com/user-attachments/assets/7626f926-a9d5-4ceb-8dfa-e354864afb0e)

![image](https://github.com/user-attachments/assets/62c9a4d6-03d9-4db1-85cf-bd13bb392e0a)



1. Connection Settings
API URL
This is the URL of the local API endpoint used for communication with the AI model
Default: http://localhost:11434/api/generate
Change this only if you are using a different server or port
Timeout (seconds)
Sets the maximum time the system waits for a response before giving up
Default: 300 seconds (5 minutes)
Increase if you experience timeout errors with large requests
2. Model Settings
System Prompt
A predefined instruction for the AI model to guide its behavior
Example: "You are a helpful assistant."
Modify this if you want the AI to respond differently (e.g., "You are a coding assistant.")
Model Selection
Choose from available AI models
Default: llama3.2-vision:latest
The list updates based on models available in your local API
3. Model Parameters
These parameters affect the AI's response style and generation behavior.

Temperature (0 to 1)
Controls randomness in responses
Lower values (0.1 - 0.3): More predictable and focused answers
Higher values (0.7 - 1.0): More creative and varied responses
Default: 0.5 (balanced output)
Top-P (Nucleus Sampling) (0 to 1)
Limits AI choices to the most probable tokens
Lower values (0.1 - 0.3): More deterministic responses
Higher values (0.7 - 1.0): More diverse responses
Default: 0.5
Top-K (1 to 100)
Similar to Top-P but limits token selection to the top K most likely words
Lower values (10 - 20): More focused responses
Higher values (50 - 100): More variation in responses
Default: 40
Context Window Size (num_ctx) (512 to 4096)
Determines how much text the AI can remember in a conversation
Higher values (2048 - 4096): Better long-term memory but more processing time
Default: 2048
Max Tokens (num_predict) (1 to 4096)
Limits the number of tokens (words/characters) generated per response
Lower values (50 - 200): Shorter responses
Higher values (500+): Longer and more detailed responses
Default: 128
Seed
Sets a fixed value for reproducible results
0: No fixed seed, responses vary
Any other number: Ensures consistent AI output across runs
Default: 0
4. Save and Apply Settings
After adjusting parameters, click Save All to apply changes
Adjust settings based on your needs for better performance and response quality
If you have any questions, feel free to reach out! Happy chatting! 😊

https://www.youtube.com/@rockbench

https://www.linkedin.com/in/seyedahmad-mehrishal/

[rockbench.ir
](https://rockbench.ir/)
