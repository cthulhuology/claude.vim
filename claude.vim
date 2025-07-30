" Claude Code Generator Plugin (Bedrock Edition)
" Author: David Goehrig dave@dloh.org
" Version: 1.0

if exists('g:loaded_claude_codegen')
    finish
endif
let g:loaded_claude_codegen = 1

" Default configuration
if !exists('g:claude_model_id')
    let g:claude_model_id = 'eu.anthropic.claude-sonnet-4-20250514-v1:0'
endif

if !exists('g:aws_region')
    let g:aws_region = 'eu-central-1'
endif

" Main function to generate code from comment
function! ClaudeGenerateCode()
    " Get current line
    let current_line = getline('.')
    let line_num = line('.')
    
    " Check if current line is a comment
    if !s:IsComment(current_line)
        echo "Current line is not a comment. Place cursor on a comment line."
        return
    endif
    
    " Extract comment text
    let comment_text = s:ExtractCommentText(current_line)
    if empty(comment_text)
        echo "No comment text found."
        return
    endif
    
    " Get file context (surrounding lines)
    let context = s:GetFileContext(line_num)
    
    " Call Claude via Bedrock
    let generated_code = s:CallBedrockAPI(comment_text, context, &filetype)
    
    if !empty(generated_code)
        " Insert generated code below the comment
        call append(line_num, split(generated_code, '\n'))
    else
        echo "Failed to generate code."
    endif
endfunction

" Check if line is a comment based on filetype
function! s:IsComment(line)
    let trimmed = trim(a:line)
    
    " Common comment patterns
    if &filetype == 'python' || &filetype == 'sh' || &filetype == 'ruby'
        return trimmed =~ '^#'
    elseif &filetype == 'javascript' || &filetype == 'typescript' || &filetype == 'java' || &filetype == 'c' || &filetype == 'cpp'
        return trimmed =~ '^//' || trimmed =~ '^/\*' || trimmed =~ '^\*'
    elseif &filetype == 'vim'
        return trimmed =~ '^"'
    elseif &filetype == 'html' || &filetype == 'xml'
        return trimmed =~ '^<!--'
    endif
    
    " Default: assume it's a comment if it starts with common comment chars
    return trimmed =~ '^[#"/\*]'
endfunction

" Extract comment text without comment markers
function! s:ExtractCommentText(line)
    let text = trim(a:line)
    
    " Remove comment markers
    if &filetype == 'python' || &filetype == 'sh' || &filetype == 'ruby'
        let text = substitute(text, '^#\s*', '', '')
    elseif &filetype == 'javascript' || &filetype == 'typescript' || &filetype == 'java' || &filetype == 'c' || &filetype == 'cpp'
        let text = substitute(text, '^//\s*', '', '')
        let text = substitute(text, '^/\*\s*', '', '')
        let text = substitute(text, '^\*\s*', '', '')
        let text = substitute(text, '\s*\*/$', '', '')
    elseif &filetype == 'vim'
        let text = substitute(text, '^"\s*', '', '')
    elseif &filetype == 'html' || &filetype == 'xml'
        let text = substitute(text, '^<!--\s*', '', '')
        let text = substitute(text, '\s*-->$', '', '')
    endif
    
    return trim(text)
endfunction

" Get surrounding context for better code generation
function! s:GetFileContext(line_num)
    let start_line = max([1, a:line_num - 10])
    let end_line = min([line('$'), a:line_num + 5])
    
    let context_lines = []
    for i in range(start_line, end_line)
        if i != a:line_num
            call add(context_lines, getline(i))
        endif
    endfor
    
    return join(context_lines, '\n')
endfunction

" Call Claude via Bedrock API to generate code
function! s:CallBedrockAPI(comment_text, context, filetype)
    " Check if AWS CLI is available
    if !executable('aws')
        echo "Error: AWS CLI not found. Please install AWS CLI and configure credentials."
        return ''
    endif
    
    " Prepare the prompt
    let prompt = s:BuildPrompt(a:comment_text, a:context, a:filetype)
    
    " Prepare Bedrock request body (Claude format)
    let messages = [ {  'role': 'user', 'content': [ { 'text': prompt } ]  } ]
    
    let inference_config = { 'maxTokens': 4096, 'temperature': 0.5,  'topP': 0.9  }
 
    let json_string = json_encode(messages)
    let inference_string = json_encode(inference_config)
    
    " Create temporary file for request body
    let temp_file = tempname()
    call writefile([json_string], temp_file)
    
    " Build AWS CLI command
    let aws_cmd = 'aws bedrock-runtime converse'
    let aws_cmd .= ' --region ' . shellescape(g:aws_region)
    let aws_cmd .= ' --model-id ' . shellescape(g:claude_model_id)
    let aws_cmd .= ' --messages ' . shellescape(json_string)
    let aws_cmd .= ' --inference-config ' . shellescape(inference_string)
    let aws_cmd .= ' --cli-binary-format raw-in-base64-out'

    echo 'Generating code...'
    " Execute AWS CLI command
    let result = system(aws_cmd)
    
    if v:shell_error != 0
        echo "Error calling Bedrock API: " . result
        return ''
    endif
    
    " Read and parse response
    try
        let parsed = json_decode(result)
        if has_key(parsed, 'output')
            return parsed.output.message.content[0].text
        elseif has_key(parsed, 'error')
            echo "Bedrock API Error: " . parsed.error.message
            return ''
        endif
    catch
        echo "Error parsing Bedrock response: " . v:exception
        return ''
    endtry
    
    return ''
endfunction

" Build prompt for Claude
function! s:BuildPrompt(comment_text, context, filetype)
    let prompt = "You are a code generator. Generate clean, functional code based on the comment description.\n\n"
    
    if !empty(a:filetype)
        let prompt .= "Language: " . a:filetype . "\n\n"
    endif
    
    if !empty(a:context)
        let prompt .= "File context:\n```\n" . a:context . "\n```\n\n"
    endif
    
    let prompt .= "Generate code for this comment: " . a:comment_text . "\n\n"
    let prompt .= "Requirements:\n"
    let prompt .= "- Generate only the code, no explanations\n"
    let prompt .= "- Match the existing code style and patterns\n"
    let prompt .= "- Make the code functional and ready to use\n"
    let prompt .= "- Don't include the original comment in your response\n"
    let prompt .= "- Don't format the response in markup, generate only the code\n"
    
    return prompt
endfunction

" Command and key mapping
command! ClaudeGenerate call ClaudeGenerateCode()

" Default key mapping (Ctrl+G)
if !hasmapto('<Plug>ClaudeGenerate')
    nmap <C-g> <Plug>ClaudeGenerate
endif

nnoremap <silent> <Plug>ClaudeGenerate :call ClaudeGenerateCode()<CR>

" Alternative key mappings you can use:
" nmap <leader>cg :ClaudeGenerate<CR>
" nmap <F5> :ClaudeGenerate<CR>
