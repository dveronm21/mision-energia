class_name ParentalChallenge
extends RefCounted
## Desafío del control parental: pregunta y respuesta esperada.

var question: String = ""
var answer: int = 0


static func make(p_question: String, p_answer: int) -> ParentalChallenge:
	var c: ParentalChallenge = ParentalChallenge.new()
	c.question = p_question
	c.answer = p_answer
	return c
