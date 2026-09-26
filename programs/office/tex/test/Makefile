TARGET = document

all: build clean

# Четырехпроходная сборка для правильной нумерации по порядку упоминания
build:
	@echo "Сборка документа (проход 1)..."
	pdflatex -interaction=nonstopmode $(TARGET).tex
	@echo "Обработка библиографии через Biber..."
	biber $(TARGET)
	@echo "Сборка документа (проход 2)..."
	pdflatex -interaction=nonstopmode $(TARGET).tex
	@echo "Финальная сборка (проход 3)..."
	pdflatex -interaction=nonstopmode $(TARGET).tex

# Просмотр результата
open:
	@echo "Открытие PDF..."
	xdg-open $(TARGET).pdf &

# Обычная очистка (clean)
# Удаляет только промежуточные файлы сборки LaTeX, но оставляет готовый PDF
clean:
	@echo "Очистка временных файлов сборки..."
	rm -f *.aux *.bbl *.bcf *.blg *.log *.run.xml *.toc *.out

# Полная очистка (distclean)
# Вызывает обычный clean, а затем удаляет и сам скомпилированный PDF
distclean: clean
	@echo "Удаление готового PDF-документа..."
	rm -f $(TARGET).pdf
