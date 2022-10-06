'reach 0.1'

const [ isFingersNumber, ZERO, ONE, TWO, THREE, FOUR, FIVE]= makeEnum(6);
const [ isGuessing, GZERO, GONE,GTWO,GTHREE,GFOUR,GFIVE,GSIX,GSEVEN,GEIGHT,GNINE,GTEN]= makeEnum(11);
const [ isOutcome, B_WIN,DRAW,A_WIN]= makeEnum(3);

const winner = (fingerA,fingerB,guessA,guessB)=>{
    if (guessA == guessB){
        const finaloutcome = DRAW;
        return finaloutcome;
    } 
    else {
        if (((fingerA+fingerB)==guessB)){
            const finaloutcome = B_WIN;
            return finaloutcome;
        }
        else {
            if(((fingerA+fingerB)==guessA)){
                const finaloutcome = A_WIN;
                return finaloutcome;
            } 
            else {
            const finaloutcome = DRAW;
            return finaloutcome;
            }
        }
    }
};


assert(winner(ZERO,ONE,GZERO,GTWO)== DRAW);
assert(winner(ZERO,TWO,GZERO,GTWO)== B_WIN);
assert(winner(TWO,ZERO,GTWO,GZERO)== A_WIN);
assert(winner(ONE,ONE,GONE,GONE)== DRAW);

forall(UInt, fingerA =>
  forall(UInt, fingerB =>
    forall(UInt, guessA =>
      forall(UInt, guessB =>
    assert(isOutcome(winner(fingerA, fingerB, guessA, guessB)))))));

forall(UInt, (fingerA) =>
  forall(UInt, (fingerB) =>       
    forall(UInt, (guess) =>
      assert(winner(fingerA, fingerB, guess, guess) == DRAW)))); 

const Player={
    ...hasRandom,
    getFinger: Fun([],UInt),
    getGuess: Fun([],UInt),
    seeOutcome: Fun([UInt],Null),
    informTimeout: Fun([],Null)
};

export const main= Reach.App(()=>{
    const Alice= Participant('Alice', {
        ...Player,
        wager: UInt,
        deadline: UInt,
    })
    const Bob = Participant('Bob', {
        ...Player,
        acceptWager: Fun([UInt],Null),
    })
    init()
    const informTimeout = () => {
        each ([Alice,Bob],()=>{
            interact.informTimeout();
        })
    }
    Alice.only(()=>{
        const wager = declassify(interact.wager);
        const deadline = declassify(interact.deadline);
    })
    Alice.publish(wager, deadline)
    .pay(wager)
    commit()

    Bob.only(()=>{
        interact.acceptWager(wager);
    })
    Bob.pay(wager)
        .timeout(relativeTime(deadline), () => closeTo(Alice, informTimeout));

    var outcome = DRAW;
    invariant(balance() == 2 * wager && isOutcome(outcome));
    while(outcome == DRAW){
        commit();
        Alice.only(()=>{
            const _fingerA = interact.getFinger();
            const _guessA = interact.getGuess();
            const [_fcommitA, _fsaltA] = makeCommitment(interact, _fingerA);
            const fcommitA = declassify(_fcommitA);
            const [_gcommitA, _gsaltA] = makeCommitment(interact, _guessA);
            const gcommitA = declassify(_gcommitA);
        });
        Alice.publish(fcommitA)
            .timeout(relativeTime(deadline), () => closeTo(Bob, informTimeout));
        commit(); 
        Alice.publish(gcommitA)
            .timeout(relativeTime(deadline), () => closeTo(Bob, informTimeout));
        commit(); 
        unknowable(Bob, Alice(_fingerA, _fsaltA));
        unknowable(Bob, Alice(_guessA, _gsaltA));

        Bob.only(()=>{
            const fingerB = declassify(interact.getFinger()); 
            const guessB = declassify(interact.getGuess());  
        });

        Bob.publish(fingerB)
            .timeout(relativeTime(deadline), () => closeTo(Alice, informTimeout));
        commit(); 
        Bob.publish(guessB)
            .timeout(relativeTime(deadline), () => closeTo(Alice, informTimeout));
        commit(); 

        Alice.only(()=>{
            const [fsaltA,fingerA] = declassify([_fsaltA,_fingerA]);
            const [gsaltA,guessA] = declassify([_gsaltA,_guessA]);
        });
        Alice.publish(fsaltA,fingerA)
            .timeout(relativeTime(deadline), () => closeTo(Bob, informTimeout));
        checkCommitment(fcommitA,fsaltA,fingerA);
        commit();
        Alice.publish(gsaltA,guessA)
            .timeout(relativeTime(deadline), () => closeTo(Bob, informTimeout));
        checkCommitment(gcommitA,gsaltA,guessA);

        outcome = winner(fingerA,fingerB,guessA,guessB);
        continue;

    }

    assert(outcome == A_WIN || outcome == B_WIN);
    transfer(2*wager).to(outcome == A_WIN ? Alice:Bob);
    commit();

    each([Alice, Bob], () => {
        interact.seeOutcome(outcome); })
})
