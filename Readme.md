	# TCL on Rails

	In progress

	### TODO
	- jobs 
		- cron?
	- controllers
		- filters -> ok
		- render method -> ok
		- scaffold implementation
		- template implementation
	- http server
		- render json - ok
		- render template - ok
		- websocket
		- workers
	- models
		- use inherits props
		- to_json
		- from_json
		- json template
		- active record?
	- cli
		- create scaffold <model name> <fields>
		- create model 	<model name> <fields>
		- create controller -model <model name>
		- create service -model <model name>
		- create templates -model <model name>

	HTTP

	Processar o conteúdo de um socket HTTP exige uma série de cuidados de segurança para evitar vulnerabilidades comuns, como injeção de código e acesso não autorizado. Aqui estão alguns passos importantes:

	1. **Validação do Conteúdo**: Sempre valide o conteúdo recebido no socket para garantir que ele está no formato esperado. Isso inclui verificar a estrutura do protocolo HTTP e o tipo dos dados.

	2. **Escape e Sanitização**: Escape e sanitize todo o conteúdo de entrada para evitar injeções de código malicioso, especialmente se os dados serão armazenados ou usados em outras partes da aplicação. Isso é particularmente importante se o conteúdo do socket for incorporado em HTML, JavaScript, SQL, ou outro formato interpretável.

	3. **Proteção Contra Buffer Overflow**: Limite o tamanho dos dados lidos pelo socket para evitar estouro de buffer. Além disso, valide e trate os cabeçalhos `Content-Length` corretamente.

	4. **HTTPS e Criptografia**: Use HTTPS sempre que possível para garantir que a comunicação entre o cliente e o servidor esteja criptografada, prevenindo ataques de interceptação (man-in-the-middle).

	5. **Controle de Timeouts**: Defina um timeout para o socket, tanto para a leitura quanto para a conexão. Isso impede que o servidor fique travado com conexões inativas ou em espera.

	6. **Autenticação e Autorização**: Implemente autenticação para identificar o cliente que está se conectando ao socket e restrinja o acesso conforme as permissões estabelecidas.

	7. **Limitação de Taxa (Rate Limiting)**: Implemente uma política de limitação de taxa para evitar que um cliente mal-intencionado sobrecarregue o servidor com um grande número de requisições.

	8. **Verificação de Assinatura e Integridade**: Utilize técnicas como HMAC ou assinaturas digitais para garantir a integridade dos dados. Isso ajuda a verificar que o conteúdo não foi modificado em trânsito.

	9. **Gerenciamento de Exceções**: Implemente um bom gerenciamento de exceções, logando erros sem expor informações sensíveis, para garantir que ataques de negação de serviço (DoS) ou outras falhas não levem ao encerramento abrupto do sistema.

	10. **Firewall e Limitação de IPs**: Configure regras de firewall para restringir os IPs que podem se conectar ao socket e evite expor o socket publicamente se não for necessário.

	Essas práticas ajudam a proteger a aplicação contra uma ampla gama de ameaças de segurança ao processar dados de um socket HTTP.
