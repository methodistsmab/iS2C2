## LIANA+ With OpenAI LLM tutorial

This demonstration uses the OpenAI API via Openrouter platform, which supports the [models](https://openrouter.ai/models).



### Prepare the API Key
Please navigate to the [Openrouter Key website](https://openrouter.ai/settings/keys) and create your own Gemini API key.

>Please put your API key in the `.env` file for security purposes.


Put your API key in a .env file as OPENROUTER_API_KEY="your-openrouter-api-key", then run:
```bash
source .env
```
```bash
export TEMP_OPENROUTER_API_KEY="$OPENROUTER_API_KEY"
```

check your API Key 
```bash
curl https://openrouter.ai/api/v1/credits \
     -H "Authorization: Bearer $TEMP_OPENROUTER_API_KEY"
```
A successful response should return something like: `{"data":{"total_credits":xxx,"total_usage":0.xxxx}}% `

> Also, keep eyes on your credits activity on this site: [key-activity](https://openrouter.ai/activity)

### Running LLM Hypothesis Generation with S2C2

Quick run with the example as follows:
```bash
python ./openrouter-api-call.py \
--cell "AST-EXC" \
--disease "Alzheimer's disease" \
--model "openai/gpt-4.1-mini" \
--significant-branches-file "../LIANA_Output/liana_cellchat_results.csv" \
--algorithm "lianaplus" \
--api-key "$OPENROUTER_API_KEY"
```

Parameter explainaiton
```bash
python ./openrouter-api-call.py  \
  --cell "(The cell communication pair for LLM-based hypothesis generation and analysis)" \
  --disease "(The disease context for LLM-based hypothesis generation to provide relevant biological context for the analysis.)" \
  --algorithm "lianaplus" \
  --llm-provider "openrouter" \
  --model "openai/gpt-4.1-mini"  \
  --api-key "$TEMP_OPENROUTER_API_KEY"
```
* For more detailed information about the parameters, please refer to [parameter-table](../../parameters.md)
* Result will be saved in the default work-directory: /results