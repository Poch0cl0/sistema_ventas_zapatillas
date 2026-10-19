import { validateEnvironment, FIREBASE_PROJECT_ID } from './environment.js';

const valid = {
  FIREBASE_PROJECT_ID,
  FIREBASE_SERVICE_ACCOUNT: './test-service-account.json',
};

describe('validateEnvironment', () => {
  it('normaliza el puerto y proporciona un valor predeterminado', () => {
    expect(validateEnvironment(valid).PORT).toBe(3000);
    expect(validateEnvironment({ ...valid, PORT: '8080' }).PORT).toBe(8080);
  });

  it.each(['', 'abc', '0', '-1', '65536', '3.5'])(
    'rechaza el puerto inválido %s',
    (PORT) => {
      expect(() => validateEnvironment({ ...valid, PORT })).toThrow('PORT');
    },
  );

  it('rechaza un proyecto distinto o ausente', () => {
    expect(() =>
      validateEnvironment({ ...valid, FIREBASE_PROJECT_ID: 'otro' }),
    ).toThrow('FIREBASE_PROJECT_ID');
    expect(() => validateEnvironment({})).toThrow('FIREBASE_PROJECT_ID');
  });

  it('exige la ruta de credenciales sin revelar su valor', () => {
    expect(() =>
      validateEnvironment({ ...valid, FIREBASE_SERVICE_ACCOUNT: ' ' }),
    ).toThrow('FIREBASE_SERVICE_ACCOUNT');
  });
});
