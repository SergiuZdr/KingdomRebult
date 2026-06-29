Plan de implementare
                      
  FAZA 1 — Real Management Loop (M2)
                                                                                                                                                                                                                                                        
  Acestea blochează experiența de bază:                                                                                                                                                                                                                 
                                                                                                                                                                                                                                                        
  1. Rebuild system — clădirile încep distruse, jucătorul le reconstruiește cu Wood+Stone. Core al poveștii.                                                                                                                                            
  2. Threat scheduling real — înlocuiește fixed every-2-turns cu un wave countdown vizibil în HUD
  3. Refactor end_turn() în faze explicite: Upkeep → Production → Training → Events → Threat resolution                                                                                                                                                 
  4. Recap extins — să reflecte toate fazele                                                                                                                                                                                                            
  5. Building groups — construction, military, intermediary, resource obtaining/processing, special                                                                                                                                                     
                                                                                                                                                                                                                                                        
  FAZA 2 — Economie & Presiune (M3)                                                                                                                                                                                                                     
                  
  6. Food upkeep — soldații consumă food/turn, mor de foame                                                                                                                                                                                             
  7. House building — mărește workforce
  8. Morale system funcțional — afectează combat, penalizări la înfrângeri/lipsuri                                                                                                                                                                      
  9. Workforce Housing — gameplay role                                                                                                                                                                                                                  
                                                                                                                                                                                                                                                        
  FAZA 3 — Combat Depth (M4)                                                                                                                                                                                                                            
                                                                                                                                                                                                                                                                                                                                                                              
  10. Dodge mechanic — există în cod dar e unused
  11. Enemy behaviors diferite — Goblin (speed), Orc (tank), Wolf (agresiv), Enemy Soldier (skill user)                                                                                                                                                 
  12. Auto-battle — optional pentru lupte ușoare                                                                                                                                                                                                        
                                                                                                                                                                                                                                                        
  FAZA 4 — Dungeon Expeditions (Main Feature)                                                                                                                                                                                                           
                                                                                                                                                                                                                                                        
  13. Dungeon/expeditions — trimiți soldați, primești rewards async pe turns                                                                                                                                                                            
                  
  FAZA 5 — Storyline & Polish                                                                                                                                                                                                                           
                  
  14. Random events la End Turn
  15. Wave system cu boss fights la intervale fixe
  16. Game over / Victory conditions                                                                                                                                                                                                                    
  17. Storyline events — mesaje narative (rege ↔ fiul regelui)
  18. Sprites, audio, animații                                                                                                                                                                                                                          
                  
  ---                                                                                                                                                                                                                                                   
  Observații tehnice importante
                                                                                                                                                                                                                                                        
  - TraitLibrary.gd are "Resilient" definit de două ori (bug potential)
  - Tavern roster nu e salvat între sesiuni (menționat în TODO)                                                                                                                                                                                         
  - Skills și cooldowns nu sunt salvate corect în save system 