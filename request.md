에디터 개발 계속할거야. 이번엔 Game Manager 카테고리를 만들어임. 여기에는 End, Toggle Input 이렇게 두 행이   
들어갈거야

둘 다 Timeline에 배치되는 이벤트 노드야. 배치 방법은 Events에서 행을 선택하고, 타임라인 위에서 우클릭을 하면 그     
위                                                                                                           
치에 배치가 되는거지. 배치된 노드는 드래그로 위치를 옮길 수 있어. 좌 우로 움직이면, Snap에 설정된 박자만     
큼                                                                                                           
Snap 되면서 움직이면됨. 상하는 Track을 옮기는 거야. 그냥 옮기면 되고, Track의 수는 Global ->                 
Editor                                                                                                       
Properties -> Track 에서 값을 수정할 수 있게 하고 기본 값은 10으로 하자                                      
.                                                          
그리고 배치된 노드 위에 마우스를 호버링하면 그 이벤트 이름이 보이게 하면 됨. C:\Users\geun\Documents\1.Project\RWD\.references\editorui3.png 이 사진 보면 무슨뜻인지 알거야.

End는 스테이지가 끝나는 시점을 말함. 에디터에서는 여기 도착하면 play하던걸 끝내면 됨.

Toggle Input은 properties를 가져. 노드 각각이 가지는 거지. Toggle 이라는 bool 값을 가지고, 기본값은 false로 하면 됨. 이건 게임내부에서 플레이어 인풋을 받게할 지 못받게 할 지를 설정하는 값임. 기본은 true로 인풋을 받을 수 있고, toggle input 노드로 변경이 가능한거지.
이런 properties가 있는 노드는 배치된 노드를 더블클릭하면, 프로퍼티와 value를 수정할 수 있는 윈도우가 나타나서 값을 수정할 수 있게 해줘야해.

End 노드의 색깔은 빨간색, Toggle input의 색깔은 주황색으로 해줘. 그리고 Toggle Input이란 Event랑 Toggle이라는 프로퍼티 이름이 뭔가 어색한거 같기도 하네. 더 좋은 이름 있으면 그걸로 해서 만들어줘