const int minimumManualScore = 90;
const int maximumManualScore = 200;

bool isValidManualScore(int score) =>
    score >= minimumManualScore && score <= maximumManualScore;

void validateManualScore(int score) {
  if (!isValidManualScore(score)) {
    throw ArgumentError.value(score, 'score', '직접 입력하는 점수는 90~200이어야 합니다.');
  }
}
