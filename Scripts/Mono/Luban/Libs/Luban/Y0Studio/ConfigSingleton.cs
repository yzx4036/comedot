using System;
using System.Collections.Concurrent;
using System.Collections.Generic;

namespace Y0Studio.Config
{
    public interface IConfigCategory
    {
        void Resolve(ConcurrentDictionary<Type, IConfigSingleton> _tables);
        
        void TranslateText(System.Func<string, string, string> translator);
    }

    public interface IConfigSingleton: IConfigCategory
    {
        void Register();
        void Destroy();
        bool IsDisposed();

    }
    public abstract class ConfigSingleton<T>: IConfigSingleton where T: ConfigSingleton<T>
    {
        private bool isDisposed;

        private static T instance;
        
        public static Func<Type, T> LoadOneConfigFunc;

        public static T Instance
        {
            get
            {
                return instance ??= LoadOneConfigFunc?.Invoke(typeof(T));
            }
        }

        void IConfigSingleton.Register()
        {
            if (instance != null)
            {
                throw new Exception($"singleton register twice! {typeof (T).Name}");
            }
            instance = (T)this;
        }

        void IConfigSingleton.Destroy()
        {
            if (this.isDisposed)
            {
                return;
            }
            this.isDisposed = true;
            
            T t = instance;
            instance = null;
            t.Dispose();
        }

        bool IConfigSingleton.IsDisposed()
        {
            return this.isDisposed;
        }

        public virtual void Dispose()
        {
        }
        
        public virtual void TrimExcess()
        {
        }
    
        public virtual string ConfigName()
        {
            return string.Empty;
        }

        public abstract void Resolve(ConcurrentDictionary<Type, IConfigSingleton> _tables);

        public abstract void TranslateText(Func<string, string, string> translator);
    }
}